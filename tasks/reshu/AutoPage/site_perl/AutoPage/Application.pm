package AutoPage::Application;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use English;
use Reshu::Utils;
require AutoPage::FCGI;

our $first_request = 1;
our $start_time; BEGIN { $start_time = time; }

sub run {
    my $pkg = shift;
    eval "require $pkg; $pkg\->run;";
    if(my $err = $@) {
	warn $err;
	&to_error_mode();
    }
}

BEGIN { *msg = \&AutoPage::FCGI::msg; }

sub server_error {
    require AutoPage::Application::Base;
    return AutoPage::Application::Base->new({}, $AutoPage::FCGI::Request)->server_error;
}

sub to_error_mode {
    msg 'script switched to error mode';
    if(!$AutoPage::FCGI::Request) {
	AutoPage::FCGI->new();
	if($AutoPage::FCGI::Request->accept()) {
	    $AutoPage::FCGI::Request->{status} = server_error;
	}
    }
    elsif($AutoPage::FCGI::Request->{initialize}) {
	die "I can't work in error mode over errors in module ".__PACKAGE__."\n";
    }
    elsif($AutoPage::FCGI::Request->{accepted}) {
	if($AutoPage::FCGI::Request->{header_sent}) {
	    $AutoPage::FCGI::Request->print("<P STYLE=\"color:red;font-size:200%\">Server error.</P>");
	}
	else {
	    delete $AutoPage::FCGI::Request->{headers_out};
	    $AutoPage::FCGI::Request->{status} = server_error;
	}
    }
    while($AutoPage::FCGI::Request->accept()) { &call_in_cgi($AutoPage::FCGI::Request); }
}

sub join_post {
    my $r = shift;
    if(($r->{env}->{REQUEST_METHOD} || '') eq 'POST') {
	my @a = @{ $r->{post} };
	my @b;
	while(@a) {
	    push @b, &escape_uri(shift @a).'='.&escape_uri(shift @a);
	}
	return join '&', @b;
    }
    else { return ''; }
}

sub call_in_cgi {
    my $r = shift;
    while(my($k,$v) = each %{$r->{env}}) { $ENV{$k} = $v; }
    my $cmd = '/usr/bin/perl -w '.&qsh($PROGRAM_NAME);
    msg "call_in_cgi cmd $cmd";
    $cmd = '/bin/echo -n '.&qsh(join_post($r)).'|'.$cmd;
    my $out = `$cmd`;
    msg "call_in_cgi exit ".sprintf('%x', $CHILD_ERROR);
    if($out eq '') { $r->{status} = server_error; return; }
    if($out =~ s/\n\nStatus: (\d*)\n\z// && $1 ne '') {
	$r->{status} = $1;
	msg "call_in_cgi status $r->{status}";
    }
    if($out eq '') { $r->{status} = server_error; return; }
    die if $r->{header_sent};
    $r->{header_sent} = 1;
    $r->print($out);
    return if $r->{status} == &AutoPage::FCGI::SERVER_ERROR;
    $r->finish();
    $r->sleep_before_restart();
    msg "restarting";
    exit;
}

1;
