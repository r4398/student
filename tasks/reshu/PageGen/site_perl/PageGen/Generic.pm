package PageGen::Generic;
use strict;
use English;
use Reshu::Utils;

use constant HTML_DEBUG => 1;

our @MonthNames = ('Без месяца', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря');

1;

sub new {
    my $class = shift;
    my $out = shift;
    my $self = bless({ out => $out }, $class);
#     warn &Reshu::Utils::d($self), ' ', &Reshu::Utils::d([caller]); $self;
}

sub join {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    my $sep = shift;
    my $first = 1;
    foreach my $item (@_) {
	if($first) { undef $first; } else {
	    if(ref($sep) eq 'CODE') { $sep->(); }
	    elsif($attr->{noescape}) { $self->print($sep); }
	    else { $self->printe($sep); }
	}
	if(ref($item) eq 'CODE') { $item->(); }
	elsif($attr->{noescape}) { $self->print($item); }
	else { $self->printe($item); }
    }
}

sub c {
    my $self = shift;
    foreach my $content (@_) {
	if(!$self->call($content)) { $self->{out}->print($content); }
    }
}

sub call {
    my $self = shift;
    my $content = shift;
    if(!defined($content)) { return 1; }
    elsif((my $r = ref $content) eq 'CODE') { $content->(); return 1; }
    elsif($r eq 'ARRAY' && @$content && (my $code = $self->can($content->[0]))) {
	$code->($self, @{$content}[1 .. $#$content]);
	return 1;
    }
    elsif(HTML_DEBUG && $r) { require Reshu::Debdata; $self->{out}->print(&Reshu::Debdata::debdata_html($content)); return 1; }
    else { return; }
}

sub form { ; }
sub input { ; }
sub td_empty { ; }
sub newpage { ; }

sub str {
    my $self = shift;
    local $self->{out} = PageGen::Generic::StrHandler->new();
    $self->ce(@_);
    return $self->{out}->{buf};
}

sub delay_push {
    my $self = shift;
    push @{$self->{delay}}, $self->{out};
    $self->{out} = PageGen::Generic::DelayHandler->new();
}

sub delay_pop {
    my $self = shift;
    my $d = shift;
    if($d->{buf}) {
	die if $d != $self->{out};
	$self->{out} = pop @{$self->{delay}};
    }
}

sub delay_print {
    my $self = shift;
    #+++ my $count = @_ ? shift : 1; # Сомнение вызывает тот момент, что мы уже могли частично извлечь стек.... На самом деле тот же эффект можно достичь несколькими последовательными вызовами delay_print
    return if !$self->{delay};
    my $d = $self->{out};
    $self->{out} = pop @{$self->{delay}};
    delete $self->{delay} unless @{$self->{delay}};
    die eval dw qw($d) if ref($d) ne 'PageGen::Generic::DelayHandler' && ref($d) ne 'PageGen::Generic::DelayHandlerPrintNext';
    $self->{out}->print(@{$d->{buf}});
    delete $d->{buf};
}

sub delay_print_next {
    my $self = shift;
    return if !$self->{delay};
    die if ref($self->{out}) ne 'PageGen::Generic::DelayHandler';
    $self->{out}{gen} = $self;
    bless($self->{out}, 'PageGen::Generic::DelayHandlerPrintNext');
}

sub delay {
    my $self = shift;
    my $delay = shift;
    if($delay) {
	my $d = $self->delay_push;
	eval { $self->ce(@_); };
	my $err = $EVAL_ERROR;
	$self->delay_pop($d);
	if($err) { die $err; }
    }
    else {
	$self->delay_print;
	$self->ce(@_);
    }
}

package PageGen::Generic::StrHandler;
use strict;

1;

sub new {
    my $class = shift;
    bless({ buf => '' }, $class);
}

sub print {
    my $self = shift;
    foreach(@_) { $self->{buf} .= $_; }
}

package PageGen::Generic::DelayHandler;
use strict;

1;

sub new {
    my $class = shift;
    bless({ buf => [] }, $class);
}

sub print {
    my $self = shift;
    push @{$self->{buf}}, @_;
}

package PageGen::Generic::DelayHandlerPrintNext;
use strict;

1;

sub print {
    my $self = shift;
    $self->{gen}->delay_print;
    $self->{gen}{out}->print(@_);
}

package PageGen::Generic::DelayOut;
use strict;
use English;
use IO::Handle;
1;

sub new {
    my $class = shift;
    my $self = bless({}, $class);
    $self->{filename} = shift;
    return $self;
}

sub DESTROY {
    my $self = shift;
    if($self->{file}) {
	unless(close $self->{file}) {
	    if($ERRNO) { warn "close($self->{filename}) failed: $ERRNO\n"; }
	    elsif($CHILD_ERROR) { warn "close($self->{filename}) failed, status: ".sprintf('%x', $CHILD_ERROR)."\n"; }
	    else { warn "close($self->{filename}) failed: NO ERROR\n";; }
	}
    }
}

sub print {
    my $self = shift;
    if(!$self->{file}) {
	open($self->{file}, $self->{filename}) || die "open($self->{filename}) failed: $ERRNO\n"
    }
    $self->{file}->print(@_);
}

package PageGen::Generic::Tee;
use strict;
use English;
use IO::Handle;
1;

sub new {
    my $class = shift;
    my $self = bless({}, $class);
    $self->{out} = [ @_ ];
    return $self;
}

sub print {
    my $self = shift;
    foreach my $h (@{$self->{out}}) { $h->print(@_); }
}
