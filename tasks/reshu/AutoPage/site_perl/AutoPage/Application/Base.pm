package AutoPage::Application::Base;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use POSIX qw(&strftime);
require Scalar::Util;
require CGI::Cookie;
use Reshu::Utils;
require AutoPage;
use AutoPage::FCGI;

1;

sub run {
    my $class = shift;
    # my %inc;
    # while(my($k,$v) = each %INC) {
    # 	if(substr($v,0,1) ne '/' || substr($v,0,10) eq '/usr/home/') { $inc{$k} = $v; }
    # }
    # warn eval dw qw($class \@_ \%inc);
    # warn eval dw qw(\@AutoPage::pages \%AutoPage::pages);
    # return;
    my $conf = $class->conf;
    my $request = AutoPage::FCGI->new;
    while($request->accept) {
	my $start_mark = time;
	my $self = $class->new($conf, $request);
	# $self->auth;
	$self->log_request;
	my $ret = eval { $self->switch; };
	if(my $err = $@) {
	    warn $err;
	    $ret = SERVER_ERROR;
	    if(!$self->{r}{header_sent}) {
		delete $self->{r}{headers_out};
		$self->{r}->no_cache(1);
		$self->{r}->send_http_header('text/html; charset='.($self->{errors_charset} || $conf->{errors_charset} || 'utf8'));
	    }
	    #TODO ??? $self->print_errors($self->{meta_errors});
	    $self->{r}->print(join '', map "<P STYLE=\"color: red;\">".&escape_html($_)."</P>\n", split "\n", $err);
	}
	if(defined $ret) { $self->{r}{status} = $ret; }
	else { $self->{r}{status} = HTTP_OK; }
	$self->log_result($start_mark);
	$self->delete_memory_recursive_links();
    }
    $request->sleep_before_restart();
}

sub conf {
    my $class = shift;
    return {};
}

sub new {
    my $class = shift;
    my $conf = shift;
    my $request = shift;
    return bless { r => $request, conf => $conf }, ref($class) || $class;
}

sub switch {
    my $self = shift;
    my $uri = $self->env->{PATH_INFO};
    return $self->check_empty_path($uri) ||
	$self->auth($uri) ||
	AutoPage::path_switch($self, $uri) ||
	$self->not_found;
}

sub check_empty_path_ignore {
    unless(defined($_[1]) && $_[1] ne '') { $_[1] = '/'; }
    return;
}

# sub check_empty_path { shift->check_empty_path_ignore(@_); }

sub check_empty_path {
    my $self = shift;
    my $uri = shift;
    unless(defined($uri) && $uri ne '') { return $self->redirect($self->proto_host_port.$self->app_path.'/'); }
    return;
}

sub auth {}

sub top_menu { ; }

sub border_page {
    my $web = shift;
    my $page = shift;
    local $page->{in_border_page} = 1;
    my $db_caption = $web->title;
    $web->rr->doc(
	{
	    title => do { if(my $pt = $page->page_title) { $db_caption.' | '.$pt; } else { $db_caption; } },
	    js => [ $page->page_js ],
	    css_links => [ $page->page_css ],
	    $page->doc_attrs,
	},
	['js', 'window.HrefBase = ', ['jss', $page->script_name], ';' ],
	['join', ' ',
	    ['a', { href => $web->app_path }, $db_caption],
	    $web->top_menu,
	],
	['hr'],
	@_,
    );
    return &HTTP_OK;
}

sub noborder_page {
    my $web = shift;
    my $page = shift;
    local $page->{in_border_page} = 1;
    $web->rr->doc(
	{ title => $web->title.' | '.$page->page_title, $page->doc_attrs },
	@_,
    );
    return &HTTP_OK;
}

sub not_found {
    my $web = shift;
    $web->rr->doc(
	{ title => $web->title },
	'Указанная страница не найдена',
    );
    return &NOT_FOUND;
}

sub forbidden {
    my $web = shift;
    $web->rr->doc(
	{ title => "БД ".$web->{meta}{label} },
	'Отказано в доступе',
    );
    return &FORBIDDEN;
}

sub redirect {
    my $web = shift;
    my $location = shift;
    $web->{r}->headers_out_set(Location => $location);
    $web->rr->doc(
	{ title => 'Страница перемещена' },
	['js', 'document.location.href = ', ['jss', $location], ';'],
	['p', 'Страница перемещена. Перейдите по ', ['a', { href => $location }, 'ссылке'], '.'],
    );
    return &REDIRECT;
}

sub server_error {
    my $web = shift;
    $web->rr->doc(
	{ title => $web->title },
	'Ошибка на сервере',
    );
    return &SERVER_ERROR;
}

sub assign_child_web {
    my $self = shift;
    my $child = shift;
    $child->{web} = $self;
    &Scalar::Util::weaken($child->{web});
}

sub assign_rr {
    my $self = shift;
    $self->{rr} = shift;
    $self->assign_child_web($self->{rr});
}

sub rr {
    my $self = shift;
    if(@_) {
	if(ref $_[0]) {
	    if($self->{rr}) { die; }
	    my $p = shift;
	    if(!$p->isa('PageGen::Generic')) { die; }
	    $self->assign_rr($p);
	}
	else {
	    my $class = shift;
	    if($self->{rr}) {
		if(!$self->{rr}->isa($class)) { die; }
	    }
	    elsif(!$class->isa('PageGen::Generic')) { die; }
	    else { $self->assign_rr($class->new($self->{r})); }
	}
    }
    elsif(!$self->{rr}) {
	require PageGen::HTML;
	$self->assign_rr(PageGen::HTML->new($self->{r}));
    }
    return $self->{rr};
}

sub log {
    my $self = shift;
    print STDERR join("\t", strftime('%x %X', localtime), hvn($>, \%ENV, 'USER'), "[$$]", $self->real_client_addr,
		      @_), "\n";
}

sub log_request {
    my $self = shift;
    my $env = $self->env;
    $self->log(n($env->{REQUEST_METHOD}), n($env->{SCRIPT_NAME}), n($env->{PATH_INFO})
	       #TODO , &n({ @{$self->{r}{post} || []} }->{action})
	);
}

sub log_result {
    my $self = shift;
    my $start_mark = shift;
    my @first_request;
    if($AutoPage::Application::first_request) {
	undef $AutoPage::Application::first_request;
	push @first_request, &seconds(time() - $AutoPage::Application::start_time);
    }
    $self->log('DONE', hvn('?', $self, qw(r status)), hvn('-', $self, 'login'), &seconds(time() - $start_mark), @first_request);
}

sub real_client_addr {
    my $self = shift;
    # Функция предназначена для исключения инфраструктуры известных прокси. Здесь такого функционала нет, но он может быть добавлен при наследовании.
    return $self->env->{REMOTE_ADDR} // 'local';
}

sub delete_memory_recursive_links {
    # Освобождение памяти после обработки запроса в случае необходимости
    # my $self = shift;
    # delete $self->{rr}{web};
    # delete $self->{rr};
}

sub env { $_[0]{r}{env}; }

sub title { 'Приложение в Паутине' }
sub app_path { $_[0]->env->{SCRIPT_NAME} }

sub proto_host_port {
    my $web = shift;
    my $env = $web->env;
    #+++ https
    return 'http://' . (
	$env->{HTTP_HOST} || ($env->{SERVER_NAME}.($env->{SERVER_PORT} != 80 ? ':'.$env->{SERVER_PORT} : ''))
    );
}

sub cookie {
    my $web = shift;
    my $name = shift;
    my $value = shift;
    my $expires = shift;
    my $h = $web->{r}->hostname();
    $web->{r}->headers_out_add('Set-Cookie' => CGI::Cookie->new(
	-name => $name, -value => $value,
	($h =~ /\./ ? (-domain => $h) : ()),
	-path => $web->{r}{env}{SCRIPT_NAME},
	($expires ? (-expires => $expires) : ()),
    )->as_string());
}
