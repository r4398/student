package AutoPage::Application;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use Reshu::Utils;

our $first_request = 1;
our $start_time; BEGIN { $start_time = time; }

sub run {
    my $pkg = shift;
    eval "require $pkg; $pkg\->run;";
    if(my $err = $@) {
	warn $err;
	xopen((my $listen_sock), "<&=", &AutoPage::FCGI::FCGI_LISTENSOCK_FILENO);
	$listen_sock->blocking(1);
	require FCGI;
	my $request = FCGI::Request();
	my $ret;
	while(($ret = $request->Accept()) >= 0) {
	    print "Content-type: text/html\r\n\r\nerror\r\n";
	    print 'fast:', d $request->IsFastCGI;
	    print "<br />\r\n";
	    print `id`;
	}
	warn eval dw qw($ret $request);
    }
}

1;
