package Student::Blog::Page::File;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use base qw(FCGI::AutoPage::JsonPage);
use Reshu::Utils;
1;
sub page_uri { 'file' }
sub page_data {
    my $page = shift;
    warn eval dw qw($page);
    return { qw(status ok) };
}
