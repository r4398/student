package FCGI::AutoPage::Application::Base;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use POSIX qw(&strftime);
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
	#TODO ??? delete $self->{rr}{web};
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

sub delete_memory_recursive_links { ; } # Освобождение памяти после обработки запроса в случае необходимости
