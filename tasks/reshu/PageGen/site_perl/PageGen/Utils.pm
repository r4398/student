package PageGen::Utils;
# Автор: Юрий Решетников <reshu@perm.ru>
use strict;
use warnings;
use English;
use Exporter 'import';

our @EXPORT;
BEGIN { require DbEdit::Request; *escape_html = \&DbEdit::Request::escape_html; }

1;

# Перенесено из DbEdit::Utils;

push @EXPORT, '&escape';
sub escape {
    if(!defined($_[0]) || $_[0] =~ /^\s*$/s) { return '&nbsp;'; }
    else { return escape_html($_[0]); }
}

push @EXPORT, '&escape_u';
sub escape_u {
    if(!defined($_[0]) or $_[0] eq '') { return '<B>NULL</B>'; }
    elsif($_[0] eq '') { return '&nbsp;'; }
    else { return escape_html($_[0]); }
}

push @EXPORT, '&escape_br';
sub escape_br {
    my $value = &escape(shift);
    $value =~ s!\n!<BR />\n!gs;
    return $value;
}

push @EXPORT, '&escape_v';
sub escape_v {
    my $v = shift;
    if(!defined $v) { return ''; }
    $v =~ s/[\#\&\=\+\x{b9}\;\"\'\%\x00-\x1f]/ sprintf('%%%02x', ord($MATCH)) /ge;
    $v =~ s/ /+/g;
    return $v;
}

push @EXPORT, '&unescape_v';
sub unescape_v {
    my $v = shift;
    if(!defined $v) { return ''; }
    $v =~ s/\+/ /g;
    $v =~ s/%([0-9a-fA-F]{2})/ chr(hex($1)) /ge;
    return $v;
}

push @EXPORT, '&jsh_quote';
sub jsh_quote { # in HTML tag attrs
    my $v = shift;
    if(!defined $v) { $v = ''; }
    $v =~ s/[\"\\]/\\$&/gs;
    $v =~ s/\r/\\r/gs;
    $v =~ s/\n/\\n/gs;
    return escape_html("\"$v\"");
}

push @EXPORT, '&jsh_prequote';
sub jsh_prequote { # in HTML tag attrs with escape_html after call
    my $v = shift;
    if(!defined $v) { $v = ''; }
    $v =~ s/[\"\\]/\\$&/gs;
    $v =~ s/\r/\\r/gs;
    $v =~ s/\n/\\n/gs;
    return qq{"$v"};
}

push @EXPORT, '&jss_quote';
sub jss_quote { #in tag <SCRIPT><!-- ... //--></SCRIPT>
    my $v = shift;
    if(!defined $v) { $v = ''; }
    $v =~ s/[\"\\]/\\$&/gs;
    $v =~ s/\r/\\r/gs;
    $v =~ s/\n/\\n/gs;
    $v =~ s/-->/--\\x3E/gs;
    return "\"$v\"";
}

