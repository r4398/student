package AutoPage::Application;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;

our $first_request = 1;
our $start_time; BEGIN { $start_time = time; }

sub run {
    my $pkg = shift;
    eval "require $pkg; $pkg\->run;";
    if(my $err = $@) {
	warn $err;
	require FCGI;
	my $request = FCGI::Request();
	while($request->Accept() >= 0) {
	    print "Content-type: text/html\r\n\r\nerror\r\n";
	    print "<br />\r\n";
	    print `id`;
	}
    }
}

1;
