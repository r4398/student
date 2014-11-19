package FCGI::AutoPage::Application::Base;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
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
