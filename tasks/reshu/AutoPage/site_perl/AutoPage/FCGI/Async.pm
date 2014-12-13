package AutoPage::FCGI::Async;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
require AnyEvent;
require AnyEvent::Handle;
use Reshu::Utils;
use base qw(AutoPage::FCGI);

1;

sub accept {
    my $self = shift;
    my $session = shift;
    my $fail = shift || sub { AE::log error => $msg; };
    $self->{sock_aw} = AE::io $self->{sock}, 0, sub {
	while(my $peer = accept my $fh, $self->{sock}) {
	    my($service, $host) = unpack_sockaddr $peer;
	    my $reading;
	    my $hdl; $hdl = AnyEvent::Handle
		fh => $fh,
		on_error => sub {
		    my($_hdl, $fatal, $msg) = @_;
		    $fail->($msg);
		    $hdl->destroy;
		    undef $hdl;
		},
		on_eof => sub {
		    if($reading || $hdl->{rbuf} ne '') { $fail->('Unexpected end of stream'); }
		    $hdl->destroy;
		    undef $hdl;
		};
	    my $error = sub {
		my $msg = shift;
		$fail->($msg);
		$hdl->destroy;
		undef $hdl;
		return;
	    };
	    my $read = sub {
		my $size = shift;
		my $cb = shift;
		return $error->('Algorithm error') if $reading;
		$reading = 1;
		$hdl->push_read(chunk => $size, sub {
		    my $data = $_[1];
		    $reading = 0;
		    $cb->($data);
		});
	    };
	    my $read_packet = sub {
		my $cb = shift;
		$read->(&AutoPage::FCGI::FCGI_HEADER_LEN, sub {
		    my($ver, $type, $req_id, $size, $padding) = unpack('CCnnC', $buf);
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
		AutoPage::FCGI::Async::Request->run($req_id, $read_packet, $error, $session);
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
    $r->{id} = shift;
    $r->read_params(@_);

    # $r->{env} = &read_params($r->{sock}, $req_id);
    # if(($r->{env}->{REQUEST_METHOD} || '') eq 'POST') {
    # 	$r->{post} = &read_stdin_post($r->{sock}, $req_id);
    # }
    # else { &read_stdin_ignore($r->{sock}, $req_id); }

    # $r->read_cookies();
    # $r->read_get();
    return;
}

sub read_params {
    my $r = shift;
    my($read_packet, $error, $session) = @_;
    my $data;
    my $wait_size = 0;
    my $read_params_pice = sub {
	$read_packet->(sub {
	    my($type, $req_id, $data_pice) = @_;
	# if($type != FCGI_PARAMS) { die; }
	# if($id != $req_id) { die; }
	# if($data_pice eq '') { if($data ne '') { die; } last; }
	# $data .= $data_pice;
	# if(length($data) < $wait_size) { next; }
	# $wait_size = 0;
	# my $offset = 0;
	# while($offset < length($data)) {
	#     my($ni, $name_len) = &get_nv_len($data, $offset);
	#     if(!$ni) { $wait_size = 4; last; }
	#     my($vi, $value_len) = &get_nv_len($data, $offset + $ni);
	#     if(!$vi) { $wait_size = $ni + 1 + $name_len; last; }
	#     if(length($data) < $offset + $ni + $vi + $name_len + $value_len) {
	# 	$wait_size = $ni + $vi + $name_len + $value_len;
	# 	last;
	#     }
	#     $offset += $ni + $vi;
	#     my $name = substr($data, $offset, $name_len);
	#     $offset += $name_len;
	#     $env->{$name} = substr($data, $offset, $value_len);
	#     $offset += $value_len;
	# }
	# $data = substr($data, $offset);
	});
    };
    $read_params_pice->();
}
