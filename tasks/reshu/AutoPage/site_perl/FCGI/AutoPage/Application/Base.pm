package FCGI::AutoPage::Application::Base;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use POSIX qw(&strftime);
require Scalar::Util;
use Reshu::Utils;
require FCGI::AutoPage;

use constant HTTP_OK => 200;
use constant REDIRECT => 302;
#use constant REDIRECT => 303;
use constant BAD_REQUEST => 400;
use constant FORBIDDEN => 403;
use constant NOT_FOUND => 404;
use constant SERVER_ERROR => 500;

1;

sub run {
    my $class = shift;
    # my %inc;
    # while(my($k,$v) = each %INC) {
    # 	if(substr($v,0,1) ne '/' || substr($v,0,10) eq '/usr/home/') { $inc{$k} = $v; }
    # }
    # warn eval dw qw($class \@_ \%inc);
    # warn eval dw qw(\@FCGI::AutoPage::pages \%FCGI::AutoPage::pages);
    # return;
    my $conf = $class->conf;
    require FCGI;
    my $request = FCGI::Request();
    unless($request->IsFastCGI) {
	$ENV{REQUEST_METHOD} //= 'TEST';
	$ENV{SCRIPT_NAME} //= $0;
	$ENV{PATH_INFO} //= '';
    }
    while($request->Accept() >= 0) {
	my $start_mark = time;
	my $self = $class->new($conf, $request);
	$self->log_request;
	my $ret = eval { $self->switch; };
	if(my $err = $@) {
	    warn $err;
	    $ret = SERVER_ERROR;
	    if(!$self->{header_sent}) {
		delete $self->{headers_out};
		$self->no_cache(1);
		$self->send_http_header('text/html; charset='.($self->{errors_charset} || $conf->{errors_charset} || 'utf8'));
	    }
	    #TODO ??? $self->print_errors($self->{meta_errors});
	    print join '', map "<P STYLE=\"color: red;\">".&escape_html($_)."</P>\n", split "\n", $err;
	}
	if(defined $ret) { $self->{status} = $ret; }
	else { $self->{status} = HTTP_OK; }
	$self->log_result($start_mark);
	$self->delete_memory_recursive_links();
    }
}

sub conf {
    my $class = shift;
    return { system_user => scalar getpwuid $> };
}

sub new {
    my $class = shift;
    my $conf = shift;
    my $request = shift;
    return bless { r => $request, conf => $conf }, ref($class) || $class;
}

sub switch {
    my $self = shift;
    my $uri = $self->{r}->GetEnvironment->{PATH_INFO};
    unless(defined($uri) && $uri ne '') { $uri = '/'; }
    if(my $rc = FCGI::AutoPage::path_switch($self, $uri)) { return $rc; }
    else { return $self->not_found; }
}

sub top_menu { ; }

sub border_page {
    my $web = shift;
    my $page = shift;
    local $page->{in_border_page} = 1;
    my $db_caption = $web->title;
    $web->rr->doc(
	{
	    title => do { if(my $pt = $page->page_title) { $db_caption.' | '.$pt; } else { $db_caption; } },
	    js => [ @DbEdit::Conf::jquery_js ],
	    css_links => [ @DbEdit::Conf::jquery_css ],
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

sub rr {
    my $self = shift;
    if(@_) {
	if(ref $_[0]) {
	    if($self->{rr}) { die; }
	    my $p = shift;
	    if(!$p->isa('PageGen::Generic')) { die; }
	    $self->{rr} = $p;
	    $self->{rr}{web} = $self;
	}
	else {
	    my $class = shift;
	    if($self->{rr}) {
		if(!$self->{rr}->isa($class)) { die; }
	    }
	    elsif(!$class->isa('PageGen::Generic')) { die; }
	    else {
		$self->{rr} = $class->new($self);
		$self->{rr}{web} = $self;
	    }
	}
    }
    elsif(!$self->{rr}) {
	require PageGen::HTML;
	$self->{rr} = PageGen::HTML->new($self);
	$self->{rr}{web} = $self;
    }
    return $self->{rr};
}

sub headers_out_add {
    my $r = shift;
    die if $r->{header_sent};
    if(@_ % 2) { die; }
    push @{$r->{headers_out}}, @_;
}

sub headers_out_set {
    my $r = shift;
    die if $r->{header_sent};
    if(@_ % 2) { die; }
    for(my $i = 0; $i < @_; ) {
	my $k = $_[$i++];
	my $v = $_[$i++];
	my $changed;
	if($r->{headers_out}) {
	    for(my $j = 0; $j < @{$r->{headers_out}}; $j++) {
		if($k eq $r->{headers_out}->[$j++]) {
		    $r->{headers_out}->[$j] = $v;
		    $changed = 1;
		    last;
		}
	    }
	}
	if(!$changed) { push @{$r->{headers_out}}, $k, $v; }
    }
}

sub no_cache {
    my $r = shift;
    my $v = shift; if(!$v) { die; }
    $r->headers_out_set(Pragma => 'no-cache');
    $r->headers_out_set('Cache-control' => 'no-cache');
}

sub send_http_header {
    my $r = shift;
    my $content = shift;
    if($r->{header_sent}) { die; }
    if(defined $content) { $r->headers_out_set('Content-Type' => $content); }
    if(!$r->{headers_out}) { dieN 5, "Empty request headers_out"; }
    $r->{header_sent} = 1;
    for(my $i = 0; $i < @{$r->{headers_out}}; ) {
	my $k = $r->{headers_out}->[$i++];
	my $v = $r->{headers_out}->[$i++];
	$r->print("$k: $v\n");
    }
    $r->print("\n");
}

sub print {
    my $r = shift;
    if(!$r->{header_sent}) { die 'no headers sent before print'; }
    print @_;
}

sub printf { my $r = shift; $r->print(sprintf(@_)); }

sub log {
    my $self = shift;
    print STDERR join("\t", strftime('%x %X', localtime), hvn($>, $self, qw(conf system_user)), "[$$]", $self->real_client_addr,
		      @_), "\n";
}

sub log_request {
    my $self = shift;
    my $env = $self->{r}->GetEnvironment;
    $self->log(n($env->{REQUEST_METHOD}), n($env->{SCRIPT_NAME}), n($env->{PATH_INFO})
	       #TODO , &n({ @{$self->{r}{post} || []} }->{action})
	);
}

sub log_result {
    my $self = shift;
    my $start_mark = shift;
    my @first_request;
    if($FCGI::AutoPage::Application::first_request) {
	undef $FCGI::AutoPage::Application::first_request;
	push @first_request, &seconds(time() - $FCGI::AutoPage::Application::start_time);
    }
    $self->log('DONE', hvn('?', $self, 'status'), hvn('-', $self, 'login'), &seconds(time() - $start_mark), @first_request);
}

sub real_client_addr {
    my $self = shift;
    # Функция предназначена для исключения инфраструктуры известных прокси. Здесь такого функционала нет, но он может быть добавлен при наследовании.
    return $self->{r}->GetEnvironment->{REMOTE_ADDR} // 'local';
}

sub delete_memory_recursive_links {
    # Освобождение памяти после обработки запроса в случае необходимости
    my $self = shift;
    delete $self->{rr}{web};
    delete $self->{rr};
}

sub env {
    my $self = shift;
    return $self->{r}->GetEnvironment;
}

sub title { 'Приложение в Паутине' }
sub app_path { $_[0]->env->{SCRIPT_NAME} }
