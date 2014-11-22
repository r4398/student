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
    if(@ARGV == 1 && $ARGV[0] eq '--test-error-mode') {
	print "OK\n";
	return;
    }
    eval "require $pkg; $pkg\->run;";
    if(my $err = $@) {
	warn $err;
	&to_error_mode();
    }
}

BEGIN { *msg = \&AutoPage::FCGI::msg; }

our @files;
sub copy_changed_files {
    my $to = shift;
    my $from = shift;
    if(@_) {
	while(@_) {
	    my $file = shift;
	    push @files, $from.'/'.$file;
	    my($s1,$t1) = (stat $to.'/'.$file)[7,9];
	    if($s1) {
		my($s2,$t2) = (stat $from.'/'.$file)[7,9];
		die unless $s2;
		next if $s1 == $s2 && $t1 == $t2;
	    }
	    system 'cp', '-p', $from.'/'.$file, $to.'/'.$file;
	    msg 'REPLACED '.$to.'/'.$file;
	}
    }
    else {
	warn 'All files mode not implemented yet';
    }
}

sub server_error {
    require AutoPage::Application::Base;
    return AutoPage::Application::Base->new({}, $AutoPage::FCGI::Request)->server_error;
}

sub to_error_mode {
    msg 'script switched to error mode';
    my $r = $AutoPage::FCGI::Request;
    if(!$r) {
	$r = AutoPage::FCGI->new();
	if($r->accept()) {
	    $r->{status} = server_error;
	}
    }
    elsif($r->{initialize}) {
	die "I can't work in error mode over errors in module ".__PACKAGE__."\n";
    }
    elsif($r->{accepted}) {
	if($r->{header_sent}) {
	    $r->print("<P STYLE=\"color:red;font-size:200%\">Server error.</P>");
	}
	else {
	    delete $r->{headers_out};
	    $r->{status} = server_error;
	}
    }
    while(!$r->{terminated}) {
	$r->accept();
	while(!$r->{accepted}) {
	    $r->accept();
	    return if $r->{terminated};
	    delete $r->{changed};
	}
	&call_in_cgi($r);
    }
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
