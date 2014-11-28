package PageGen::XML;

use strict;
use English;
use base qw(PageGen::Generic);
use Reshu::Utils;

1;

sub escape_data {
    my $str = shift;
    return '' unless defined($str);
    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g; # из совместимости если входит в комбинацию ]]> не являющейся окончанием CDATA
    return $str;
}

sub escape_param {
# для экранирования значений параметров, пока не используется
    my $str = shift;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&apos;/g;
    return $str;
}

sub check_tag_name {
    my $name = shift;
    if($name !~ m/^[a-zA-Z]/
	|| $name =~ m/^xml\b/
	|| $name =~ m/^XML\b/
	|| $name =~ m/[\s.\$'"]/
    ){
	die "Нарушено правило наименования тэга XML '$name'"
    }
}

sub print_attr {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    my $print_if_empty = shift;
    if($print_if_empty || defined($value) ) {
	&verify_el($name);
	$self->{out}->print(' ', $name, '="', &escape_param($value), '"');
    }
}

sub ce {
    my $self = shift;
    foreach my $content (@_) {
	if(!$self->call($content)) { $self->{out}->print(&escape_data($content)); }
    }
}

sub doc {
    my $self = shift;
    local $self->{doc_attr} = my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    if(!defined($attr->{charset})) { $attr->{charset} = 'koi8-r'; }
    if(&n($attr->{http}, 1)) {
	if(!defined($attr->{no_cache}) || $attr->{no_cache}) { $self->{out}->no_cache(1); }
# 	$self->{out}->send_http_header('text/xml; charset='.$attr->{charset});
	$self->{out}->send_http_header('application/msexcel; charset='.$attr->{charset});
    }
    $self->{out}->print('<?xml version="1.0" encoding="', &escape_param($attr->{charset}), '"?>
');
    foreach my $content (@_) { if(!$self->call($content)) { die "Ошибка формата: ", &d($content); } }
}

sub tag {
    my $self = shift;
    my $tag = shift;
    &check_tag_name($tag);
    my($attr,$xml_attr);
    if(@_) {
	if(ref($_[0]) eq 'HASH') { $attr = shift; }
	elsif(ref($_[0]) eq 'ARRAY') { $xml_attr = shift; }
    }
    if($attr->{indent}) {
	$self->{indent_level}++;
	$self->{out}->print("\n", ('    ' x $self->{indent_level}));
    }
    eval {
	$self->{out}->print("<$tag", $attr->{raw_attr} ? (' ', $attr->{raw_attr}) : ());
	unless($xml_attr) {
	    $xml_attr = $attr;
	    if(ref($attr) eq 'HASH') {
		foreach my $k (qw(raw_attr noescape indent)) {
		    if(exists($attr->{$k})) {
			$xml_attr = @_ && (ref($_[0]) eq 'HASH' || ref($_[0]) eq 'ARRAY') ? shift : {};
			last;
		    }
		}
	    }
	}
	if(ref($xml_attr) eq 'HASH') {
	    while(my($k,$v) = each %$xml_attr) { $self->print_attr($k, $v); }
	}
	else {
	    my @a = @$xml_attr;
	    while(@a) { my $k = shift @a; my $v = shift @a; $self->print_attr($k, $v); }
	}
	if(@_) {
	    $self->{out}->print(">");
	    if($attr->{noescape}) { $self->c(@_); } else { $self->ce(@_); }
	    if($attr->{indent}) {
		$self->{out}->print("\n", ('    ' x $self->{indent_level}));
	    }
	    $self->{out}->print("</$tag>");
	}
	else {
	    $self->{out}->print(" />");
	}
    };
    my $err = $EVAL_ERROR;
    if($attr->{indent}) {
	$self->{indent_level}--;
    }
    die $err if $err;
}
