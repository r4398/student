package PageGen::Utils;
# Автор: Юрий Решетников <reshu@perm.ru>
use strict;
use warnings;
use English;
use Exporter 'import';

our(@EXPORT,%EXPORT_TAGS);
1;

push @EXPORT, @{$EXPORT_TAGS{HTTP_STATUS} = [qw(&HTTP_OK &REDIRECT &BAD_REQUEST &NOT_FOUND &FORBIDDEN &SERVER_ERROR)]};
use constant HTTP_OK => 200;
use constant REDIRECT => 302;
#use constant REDIRECT => 303;
use constant BAD_REQUEST => 400;
use constant FORBIDDEN => 403;
use constant NOT_FOUND => 404;
use constant SERVER_ERROR => 500;

my @escape_html_chars;
$escape_html_chars[ord '<'] = '&lt;';
$escape_html_chars[ord '>'] = '&gt;';
$escape_html_chars[ord '&'] = '&amp;';
$escape_html_chars[ord '"'] = '&quot;';

push @EXPORT, '&escape_html';
sub escape_html {
    my $s = shift;
    $s =~ s/[<>&\"]/$escape_html_chars[ord $MATCH]/ge;
    return $s;
}

push @EXPORT, '&escape_uri';
sub escape_uri {
    my $s = shift;
    $s =~ s/[+?\"\'<>]/sprintf('%%%02X', ord $MATCH)/ge;
    $s =~ s/ /+/g;
    return $s;
}

push @EXPORT, '&unescape_uri';
sub unescape_uri {
    my $s = shift;
    if(defined $s) {
	$s =~ s/\+/ /g;
	$s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    }
    return $s;
}

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

