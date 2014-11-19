package Student::Blog::Page::Index;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use base qw(FCGI::AutoPage::Page);
use Reshu::Utils;
1;
sub page_uri { '' }
sub page_content {
    my $page = shift;
    warn eval dw qw($page);
    return HTTP_OK;
}
