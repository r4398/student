package FCGI::AutoPage::Application::Base;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use POSIX qw(&strftime);
use Reshu::Utils;

1;

sub run {
    my $class = shift;
    my %inc;
    while(my($k,$v) = each %INC) {
	if(substr($v,0,1) ne '/' || substr($v,0,10) eq '/usr/home/') { $inc{$k} = $v; }
    }
    warn eval dw qw($class \@_ \%inc);
}

sub log {
    my $self = shift;
    print STDERR join("\t", strftime('%x %X', localtime), hvn($<, $self, 'system_user'), "[$$]", $self->real_client_addr, @_), "\n";
}

sub log_request {
    my $self = shift;
    my $env = $self->{r}->GetEnvironment;
    $self->log($env->{REQUEST_METHOD}, $env->{SCRIPT_NAME}, &n($env->{PATH_INFO})
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
