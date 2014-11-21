package AutoPage::FCGI;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use English;
use Exporter 'import';
use IO::Handle;
use POSIX 'strftime', 'errno_h';
use Reshu::Utils;

our @EXPORT;

1;

use constant STDOUT_BUF_SIZE => 4096;

###############
# Fields:
###############
# accept
# accept_wh
# accept_inc
# accepted
# terminated
# changed
# initialize
# not_fast_cgi
# status
# headers_out
# header_sent
# stdout_buf
# id
# env
# post
# get
# cookies
###############

use constant FCGI_LISTENSOCK_FILENO =>  0;
use constant FCGI_HEADER_LEN	    =>  8;
use constant FCGI_VERSION_1         =>  1;
use constant FCGI_BEGIN_REQUEST     =>  1;
use constant FCGI_ABORT_REQUEST     =>  2;
use constant FCGI_END_REQUEST       =>  3;
use constant FCGI_PARAMS            =>  4;
use constant FCGI_STDIN             =>  5;
use constant FCGI_STDOUT            =>  6;
use constant FCGI_STDERR            =>  7;
use constant FCGI_DATA              =>  8;
use constant FCGI_GET_VALUES        =>  9;
use constant FCGI_GET_VALUES_RESULT => 10;
use constant FCGI_UNKNOWN_TYPE      => 11;
use constant FCGI_MAXTYPE => FCGI_UNKNOWN_TYPE;
use constant FCGI_NULL_REQUEST_ID   =>  0;
use constant FCGI_KEEP_CONN         =>  1;
use constant FCGI_RESPONDER         =>  1;
use constant FCGI_AUTHORIZER        =>  2;
use constant FCGI_FILTER            =>  3;
use constant FCGI_REQUEST_COMPLETE  =>  0;
use constant FCGI_CANT_MPX_CONN     =>  1;
use constant FCGI_OVERLOADED        =>  2;
use constant FCGI_UNKNOWN_ROLE      =>  3;
use constant FCGI_MAX_CONNS  => "FCGI_MAX_CONNS";
use constant FCGI_MAX_REQS   => "FCGI_MAX_REQS";
use constant FCGI_MPXS_CONNS => "FCGI_MPXS_CONNS";

push @EXPORT, qw(&HTTP_OK &REDIRECT &BAD_REQUEST &NOT_FOUND &FORBIDDEN &SERVER_ERROR);
use constant HTTP_OK => 200;
use constant REDIRECT => 302;
#use constant REDIRECT => 303;
use constant BAD_REQUEST => 400;
use constant FORBIDDEN => 403;
use constant NOT_FOUND => 404;
use constant SERVER_ERROR => 500;

sub new {
    my $class = shift;
    my $not_single = shift; # Он же not_fast
    our $Request;
    if($Request) { die; }
    my $r = {};
    if($not_single) {
	bless($r, 'AutoPage::FCGI::NotFast');
    }
    else {
	open($r->{listen_sock}, "<&=", FCGI_LISTENSOCK_FILENO) || die $ERRNO;
	if(!defined(getpeername($r->{listen_sock})) && $ERRNO == ENOTSOCK) {
	    bless($r, 'AutoPage::FCGI::NotFast');
	}
	else {
	    bless($r, $class);
	    $r->{listen_sock}->blocking(0);
	    $r->check_ev;
	}
	$Request = $r;
    }
    if(!$ENV{USER}) { $ENV{USER} = getpwuid($UID); }
    return $r;
}

sub msg {
    print STDERR join("\t", strftime('%x %X', localtime), hvn($>, \%ENV, 'USER'), "[$$]", @_), "\n";
}

sub sleep_before_restart {
    my $r = shift;
    if((my $run = time() - $AutoPage::Application::start_time) < 20) {
	my $s = 20 - $run;
	msg "Рестарт слишком рано, подождем $s секунд";
	sleep($s);
    }
}

sub check_ev {
    my $r = shift;
    if($EV::VERSION) {
	msg "EV:$EV::VERSION";
	$r->{accept} = \&accept_ev;
	$r->{accept_wh} = &EV::io($r->{listen_sock}, &EV::READ(), sub {
	    if($r->{changed}) {
		&EV::unloop();
	    }
	    elsif(CORE::accept($r->{sock}, $r->{listen_sock})) {
		$r->{accepted} = 1;
		&EV::unloop();
	    }
	    elsif($ERRNO != EAGAIN) {
		$r->{terminated} = 1;
		warn "accept() failed: $ERRNO\n";
		&EV::unloop();
	    }
	});
	foreach my $f ($0, values %INC) { if(defined $f) {
	    $r->{accept_inc}{$f} = &EV::stat($f, 0, sub {
		unless($r->{changed}) {
		    $r->{changed} = 1;
		    msg 'changed', $f;
		}
	    });
	} }
    }
    else {
	msg "EV not found, using select";
	$r->{accept} = \&accept_select;
    }
}

sub accept_ev { &EV::run(); }

sub accept_select {
    my $r = shift;
    # TODO Реализовать рестарт при изменениях и в этом варианте
    my $sel_bits = '';
    vec($sel_bits, $r->{listen_sock}->fileno(), 1) = 1;
    while(1) {
	while(1) {
	    my $res = select($sel_bits, undef, undef, undef);
	    if($res < 0) {
		if($ERRNO == EINTR) {
		    if($r->{terminated}) { return; }
		}
		else { die "select() failed: $ERRNO\n"; }
	    }
	    elsif($res > 0) { last; }
	}
	if(CORE::accept($r->{sock}, $r->{listen_sock})) {
	    $r->{accepted} = 1;
	    return;
	}
	elsif($ERRNO != EAGAIN) {
	    die "accept() failed: $ERRNO\n";
	}
    }
}

sub accept {
    my $r = shift;
    if($r->{accepted}) { $r->finish(); }
    if($r->{terminated}) { return; }
    $r->{initialize} = 1;
    $r->{accept}->($r);
    if($r->{terminated}) { return; }
    elsif($r->{changed}) {
	#TODO check for errors
	return;
	# exec $0;
	# die "exec '$0' failed: $!";
    }
    die eval dw qw($r) unless $r->{accepted};
    my($type, $req_id, $data) = &read_packet($r->{sock});
    if(!defined $type) { last; }
    my($role, $flags) = unpack("nC", $data);
    if($type != FCGI_BEGIN_REQUEST) { die; }
    if($role != FCGI_RESPONDER) { die; }

    $r->{id} = $req_id;
    $r->{req} = {};
    $r->{env} = &read_params($r->{sock}, $req_id);
    if(($r->{env}->{REQUEST_METHOD} || '') eq 'POST') {
	$r->{post} = &read_stdin_post($r->{sock}, $req_id);
    }
    else { &read_stdin_ignore($r->{sock}, $req_id); }

    $r->read_cookies();
    $r->read_get();

    $r->{stdout_buf} = '';

    delete $r->{initialize};

    return 1;
}

sub flush {
    my $r = shift;
    if($r->{stdout_buf} ne '') {
	&write_packet($r->{sock}, FCGI_STDOUT, $r->{id}, $r->{stdout_buf});
	$r->{stdout_buf} = '';
    }
}

sub finish {
    my $r = shift;
    if(!$r->{header_sent}) {
	if($r->{headers_out}) { $r->send_http_header(); }
	elsif($r->{status} && $r->{status} != HTTP_OK) { ; }
	else { dieN 5, "Empty output page"; }
    }
    $r->flush();
    &write_packet($r->{sock}, FCGI_STDOUT, $r->{id}, '');
    if(!defined $r->{status}) { $r->{status} = HTTP_OK; }
    &write_packet($r->{sock}, FCGI_END_REQUEST, $r->{id},
	pack('NC', $r->{status}, FCGI_REQUEST_COMPLETE)."\0\0\0");
    $r->{sock}->close() || warn $ERRNO;
    delete @{$r}{qw(sock accepted id env post get cookies status
	headers_out header_sent stdout_buf)};
}

sub terminate {
    my $r = shift;
    $r->{terminated} = 1;
}

sub read_cookies {
    my $r = shift;
    $r->{cookies_all} = defined($r->{env}->{HTTP_COOKIE}) ?
	[ map &unescape_uri($_),
	map { my @p = split(/=/, $_, 2); @p == 1 ? (@p, undef) : @p; }
	split /;\s*/, $r->{env}->{HTTP_COOKIE} ] : [];
    $r->{cookies} = {};
    for(my $i = 0; $i < @{$r->{cookies_all}}; ) {
	my $k = $r->{cookies_all}->[$i++];
	my $v = $r->{cookies_all}->[$i++];
	if(!exists $r->{cookies}->{$k}) { $r->{cookies}->{$k} = $v; }
    }
}

sub read_get {
    my $r = shift;
    if(defined $r->{env}->{QUERY_STRING}) {
	$r->{get} = [ map &unescape_uri($_),
	map { my @p = split(/=/, $_, 2); @p == 1 ? (@p, undef) : @p; }
	split(/&/, $r->{env}->{QUERY_STRING}) ];
    }
}

sub print {
    my $r = shift;
    if(!$r->{header_sent}) { die 'no headers sent before print'; }
    foreach my $s (@_) {
	if(!defined $s) { warnN 3, "undefined value in args"; next; }
	if(length($r->{stdout_buf}) + length($s) < STDOUT_BUF_SIZE) {
	    $r->{stdout_buf} .= $s;
	}
	else {
	    my $n = STDOUT_BUF_SIZE - length($r->{stdout_buf});
	    $r->{stdout_buf} .= substr($s, 0, $n);
	    &write_packet($r->{sock}, FCGI_STDOUT, $r->{id}, $r->{stdout_buf});
	    while(length($s) - $n >= STDOUT_BUF_SIZE) {
		&write_packet($r->{sock}, FCGI_STDOUT, $r->{id},
			substr($s, $n, STDOUT_BUF_SIZE));
		$n += STDOUT_BUF_SIZE;
	    }
	    $r->{stdout_buf} = substr($s, $n);
	}
    }
}

sub printf { my $r = shift; $r->print(sprintf(@_)); }

sub read_packet {
    my $sock = shift;
    my $r1 = $sock->read(my $buf, FCGI_HEADER_LEN);
    if(!defined $r1) { die $ERRNO; } elsif($r1 == 0) { return; }
    my($ver, $type, $req_id, $size, $padding) = unpack('CCnnC', $buf);
    if($ver != FCGI_VERSION_1) { die "Unknow FCGI protocol version\n"; }
    my $data = '';
    if($size) {
	my $r2 = $sock->read($data, $size);
	if(!defined $r2) { die $ERRNO; }
	elsif($r2 != $size) { die "Unexpected end of stream"; }
    }
    if($padding) {
	my $r2 = $sock->read(my $temp, $padding);
	if(!defined $r2) { die $ERRNO; }
	elsif($r2 != $padding) { die "Unexpected end of stream"; }
    }
    return $type, $req_id, $data;
}

sub write_packet {
    my $sock = shift;
    my $type = shift;
    my $req_id = shift;
    my $data = shift;
    my $padding = (8 - length($data) % 8) % 8;
    my $header = pack('CCnnCC', FCGI_VERSION_1, $type, $req_id,
	length($data), $padding, 0);
    $sock->printflush($header, $data, $padding ? ("\0" x $padding) : ());
}

sub get_nv_len {
    my $data = shift;
    my $offset = shift;
    if($offset + 1 > length($data)) { return; }
    my $len = unpack('C', substr($data, $offset, 1));
    if(!($len & 0x80)) { return 1, $len; }
    if($offset + 4 > length($data)) { return; }
    $len = unpack('N', pack('C', $len & 0x7F).substr($data, $offset + 1, 3));
    return 4, $len;
}

sub read_params {
    my $sock = shift;
    my $req_id = shift;
    my $env = {};
    my $data = '';
    my $wait_size = 0;
    while(1) {
	my($type, $id, $data_pice) = &read_packet($sock);
	if($type != FCGI_PARAMS) { die; }
	if($id != $req_id) { die; }
	if($data_pice eq '') { if($data ne '') { die; } last; }
	$data .= $data_pice;
	if(length($data) < $wait_size) { next; }
	$wait_size = 0;
	my $offset = 0;
	while($offset < length($data)) {
	    my($ni, $name_len) = &get_nv_len($data, $offset);
	    if(!$ni) { $wait_size = 4; last; }
	    my($vi, $value_len) = &get_nv_len($data, $offset + $ni);
	    if(!$vi) { $wait_size = $ni + 1 + $name_len; last; }
	    if(length($data) < $offset + $ni + $vi + $name_len + $value_len) {
		$wait_size = $ni + $vi + $name_len + $value_len;
		last;
	    }
	    $offset += $ni + $vi;
	    my $name = substr($data, $offset, $name_len);
	    $offset += $name_len;
	    $env->{$name} = substr($data, $offset, $value_len);
	    $offset += $value_len;
	}
	$data = substr($data, $offset);
    }
    return $env;
}

sub read_stdin {
    my $sock = shift;
    my $req_id = shift;
    my $data = '';
    while(1) {
	my($type, $id, $data_pice) = &read_packet($sock);
	if($type != FCGI_STDIN) { die; }
	if($id != $req_id) { die; }
	if($data_pice eq '') { last; }
	$data .= $data_pice;
    }
    return $data;
}

sub read_stdin_ignore {
    my $sock = shift;
    my $req_id = shift;
    while(1) {
	my($type, $id, $data_pice) = &read_packet($sock);
	if($type != FCGI_STDIN) { die; }
	if($id != $req_id) { die; }
	if($data_pice eq '') { last; }
    }
}

sub read_stdin_post {
    my $sock = shift;
    my $req_id = shift;
    my $post = [];
    my $data = '';
    while(1) {
	my($type, $id, $data_pice) = &read_packet($sock);
	if($type != FCGI_STDIN) { die; }
	if($id != $req_id) { die; }
	$data .= $data_pice;
	my @d = split /&/, $data;
	if($data_pice ne '') { $data = pop @d; }
	foreach my $p (@d) {
	    my @p = split(/=/, $p, 2);
	    push @$post, map &unescape_uri($_), @p;
	    if(@p == 1) { push @$post, undef; }
	}
	if($data_pice eq '') { last; }
    }
    return $post;
}

sub headers_out_add {
    my $r = shift;
    die if $r->{header_sent};
    if(@_ % 2) { die; }
    push @{$r->{headers_out}}, @_;
}

sub headers_out_set {
    my $r = shift;
    die if $r->{header_sent};
    if(@_ % 2) { die; }
    for(my $i = 0; $i < @_; ) {
	my $k = $_[$i++];
	my $v = $_[$i++];
	my $changed;
	if($r->{headers_out}) {
	    for(my $j = 0; $j < @{$r->{headers_out}}; $j++) {
		if($k eq $r->{headers_out}->[$j++]) {
		    $r->{headers_out}->[$j] = $v;
		    $changed = 1;
		    last;
		}
	    }
	}
	if(!$changed) { push @{$r->{headers_out}}, $k, $v; }
    }
}

sub no_cache {
    my $r = shift;
    my $v = shift; if(!$v) { die; }
    $r->headers_out_set(Pragma => 'no-cache');
    $r->headers_out_set('Cache-control' => 'no-cache');
}

sub send_http_header {
    my $r = shift;
    my $content = shift;
    if($r->{header_sent}) { die; }
    if(defined $content) { $r->headers_out_set('Content-Type' => $content); }
    if(!$r->{headers_out}) { dieN 5, "Empty request headers_out"; }
    $r->{header_sent} = 1;
    for(my $i = 0; $i < @{$r->{headers_out}}; ) {
	my $k = $r->{headers_out}->[$i++];
	my $v = $r->{headers_out}->[$i++];
	$r->print("$k: $v\n");
    }
    $r->print("\n");
}

sub hostname {
    my $r = shift;
    return $r->{env}->{HTTP_HOST}
	? (split /:/, $r->{env}->{HTTP_HOST})[0]
	: $r->{env}->{SERVER_NAME};
}

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

package AutoPage::FCGI::NotFast;
use strict;
use warnings;
use bytes;
use English;
use IO::Handle;
use Reshu::Utils;

1;

sub accept {
    my $r = shift;
    if($r->{accepted}) { $r->finish(); return; }

    $r->{env} = { %ENV };
    if(!defined $r->{env}{REQUEST_METHOD}) { $r->{env}{REQUEST_METHOD} = ''; }
    elsif($r->{env}{REQUEST_METHOD} eq 'POST') {
	$r->{post} = &read_stdin_post();
    }
    if(!defined $r->{env}{REQUEST_URI}) { $r->{env}{REQUEST_URI} = ''; }
    $r->{env}{SCRIPT_NAME} ||= $PROGRAM_NAME;
    $r->{env}{HTTP_USER_AGENT} ||= '';
    $r->{env}{REMOTE_ADDR} ||= '127.0.0.1';
    $r->{env}{SERVER_NAME} ||= 'localhost';
    $r->{env}{SERVER_PORT} ||= 80;

    &AutoPage::FCGI::read_cookies($r);
    &AutoPage::FCGI::read_get($r);

    $r->{accepted} = 1;

    return 1;
}

sub flush { my $r = shift; STDOUT->flush(); }

sub finish {
    my $r = shift;
    if(!$r->{header_sent}) {
	if($r->{headers_out}) { $r->send_http_header(); }
	elsif($r->{status} && $r->{status} != AutoPage::FCGI::HTTP_OK) { ; }
	else { dieN 5, "Empty output page"; }
    }
    print "\n\nStatus: ", &Reshu::Utils::n($r->{status}), "\n";
}

sub print { my $r = shift; print @_; }
sub printf { my $r = shift; printf @_; }

sub read_stdin_post {
    my $post = [];
    my $data = '';
    while(1) {
	read(STDIN, my $data_pice, 4096);
	$data .= $data_pice;
	my @d = split /&/, $data;
	if($data_pice ne '') { $data = pop @d; }
	foreach my $p (@d) {
	    my @p = split(/=/, $p, 2);
	    push @$post, map &AutoPage::FCGI::unescape_uri($_), @p;
	    if(@p == 1) { push @$post, undef; }
	}
	if($data_pice eq '') { last; }
    }
    return $post;
}

sub save_all_modules_to_check { ; }
sub save_home_modules_to_check { ; }
sub no_cache { ; }
sub sleep_before_restart { ; }

BEGIN {
    foreach my $f (qw(
	headers_out_add headers_out_set send_http_header hostname
	main_work_dbi main_work real_client_addr
    )) { eval "*$f = \\&AutoPage::FCGI::$f;"; warn if $EVAL_ERROR; }
}
