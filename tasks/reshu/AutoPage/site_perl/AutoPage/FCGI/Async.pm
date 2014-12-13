package AutoPage::FCGI::Async;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use AnyEvent ();
require AnyEvent::Handle;
use Reshu::Utils;
use PageGen::Utils qw(unescape_uri);
use base qw(AutoPage::FCGI);

1;

sub accept {
    my $self = shift;
    my $session = shift;
    my $fail = shift || sub { AE::log error => shift; };
    $self->{sock_aw} = AE::io $self->{sock}, 0, sub {
	while(my $peer = accept my $fh, $self->{sock}) {
	    my($service, $host) = unpack_sockaddr $peer;
	    my $reading;
	    my $r;
	    my $sock_aw; $sock_aw = new AnyEvent::Handle
		fh => $fh,
		on_error => sub {
		    my($hdl, $fatal, $msg) = @_;
		    $fail->($msg);
		    $hdl->destroy;
		    undef $sock_aw;
		    delete $r->{sock_aw};
		},
		on_eof => sub {
		    my($hdl) = @_;
		    if($reading || $hdl->{rbuf} ne '') { $fail->('Unexpected end of stream'); }
		    $hdl->destroy;
		    undef $sock_aw;
		    delete $r->{sock_aw};
		};
	    my $error = sub {
		my $msg = shift;
		$fail->($msg);
		if($sock_aw) {
		    $sock_aw->destroy;
		    undef $sock_aw;
		    delete $r->{sock_aw};
		}
		return;
	    };
	    my $read = sub {
		my $size = shift;
		my $cb = shift;
		return $error->('Algorithm error') if $reading;
		$reading = 1;
		$sock_aw->push_read(chunk => $size, sub {
		    my $data = $_[1];
		    $reading = 0;
		    $cb->($data);
		});
	    };
	    my $read_packet = sub {
		my $cb = shift;
		$read->(&AutoPage::FCGI::FCGI_HEADER_LEN, sub {
		    my($ver, $type, $req_id, $size, $padding) = unpack('CCnnC', shift);
		    return $error->('Unknow FCGI protocol version:'.$ver) if $ver != &AutoPage::FCGI::FCGI_VERSION_1;
		    my $read_packet_data = sub {
			my $data = shift;
			my $read_packet_padding = sub {
			    $cb->($type, $req_id, $data);
			};
			if($padding) { $read->($padding, $read_packet_padding); } else { $read_packet_padding->(''); }
		    };
		    if($size) { $read->($size, $read_packet_data); } else { $read_packet_data->(''); }
		});
	    };
	    $read_packet->(sub {
		my($type, $req_id, $data) = @_;
		my($role, $flags) = unpack("nC", $data);
		return $error->('*') if $type != &AutoPage::FCGI::FCGI_BEGIN_REQUEST;
		return $error->('*') if $role != &AutoPage::FCGI::FCGI_RESPONDER;
		$r = AutoPage::FCGI::Async::Request->run($sock_aw, $req_id, $read_packet, $error, $session);
	    });
	}
   };
}

package AutoPage::FCGI::Async::Request;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use Reshu::Utils;
use base qw(AutoPage::FCGI);

1;

sub run {
    my $class = shift;
    my $r = bless { stdout_buf => '' }, ref($class) || $class;
    $r->{sock_aw} = shift;
    $r->{id} = shift;
    $r->read_params(@_);
    return $r;
}

sub read_params {
    my $r = shift;
    my($read_packet, $error, $session) = @_;
    my $data = '';
    my $wait_size = 0;
    my $read_params_pice; $read_params_pice = sub {
	$read_packet->(sub {
	    my($type, $req_id, $data_pice) = @_;
	    return $error->('*') if $type != &AutoPage::FCGI::FCGI_PARAMS;
	    return $error->('*') if $req_id != $r->{id};
	    if($data_pice eq '') { if($data ne '') { $error->('*'); } else { $r->read_stdin($read_packet, $error, $session); } return; }
	    $data .= $data_pice;
	    if(length($data) >= $wait_size) {
		$wait_size = 0;
		my $offset = 0;
		while($offset < length($data)) {
		    my($ni, $name_len) = &AutoPage::FCGI::get_nv_len($data, $offset);
		    if(!$ni) { $wait_size = 4; last; }
		    my($vi, $value_len) = &AutoPage::FCGI::get_nv_len($data, $offset + $ni);
		    if(!$vi) { $wait_size = $ni + 1 + $name_len; last; }
		    if(length($data) < $offset + $ni + $vi + $name_len + $value_len) {
			$wait_size = $ni + $vi + $name_len + $value_len;
			last;
		    }
		    $offset += $ni + $vi;
		    my $name = substr($data, $offset, $name_len);
		    $offset += $name_len;
		    $r->{env}{$name} = substr($data, $offset, $value_len);
		    $offset += $value_len;
		}
		$data = substr($data, $offset);
	    }
	    $read_params_pice->();
	});
    };
    $read_params_pice->();
}

sub read_stdin {
    my $r = shift;
    my($read_packet, $error, $session) = @_;
    my $parse;
    if(($r->{env}->{REQUEST_METHOD} || '') eq 'POST') {
	my $data = '';
	$parse = sub {
	    my $data_pice = shift;
	    $data .= $data_pice;
	    my @d = split /&/, $data;
	    if($data_pice ne '') { $data = pop @d; }
	    foreach my $p (@d) {
		my @p = split(/=/, $p, 2);
		push @{$r->{post}}, map &unescape_uri($_), @p;
		if(@p == 1) { push @{$r->{post}}, undef; }
	    }
	};
    }
    else { $parse = sub {}; }
    my $read; $read = sub {
	$read_packet->(sub {
	    my($type, $req_id, $data_pice) = @_;
	    return $error->('*') if $type != &AutoPage::FCGI::FCGI_STDIN;
	    return $error->('*') if $req_id != $r->{id};
	    $parse->($data_pice);
	    if($data_pice eq '') { $r->session($read_packet, $error, $session); } else { $read->(); }
	});
    };
    $read->();
}

sub session {
    my $r = shift;
    my($read_packet, $error, $session) = @_;
    $r->read_cookies();
    $r->read_get();
    $r->{accepted} = 1;
    $session->($r);
}

sub write_packet {
    my $r = shift;
    my $type = shift;
    my $req_id = shift;
    my $data = shift;
    my $padding = (8 - length($data) % 8) % 8;
    my $header = pack('CCnnCC', &AutoPage::FCGI::FCGI_VERSION_1, $type, $req_id, length($data), $padding, 0);
    $r->{sock_aw}->push_write($header . $data . ($padding ? ("\0" x $padding) : ''));
}

sub close_socket {
    my $r = shift;
    $r->{sock_aw}->push_shutdown;
}

sub DESTROY {
    my $r = shift;
    $r->finish if $r->{accepted};
}
