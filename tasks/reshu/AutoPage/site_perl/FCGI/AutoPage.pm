package FCGI::AutoPage;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use IO::Dir;
use Reshu::Utils;

our @pages;
our %pages;
our %EXCLUDE_PAGES;

1;

sub import {
    my $pkg = shift;
    my $callpkg = caller;
    if($pkg eq __PACKAGE__) { return; }
    &load_folder($pkg, @_);
    push @pages, $pkg;
}

sub load_folder {
    my $pkg = shift;
    if(@_ == 1 && $_[0] eq ':all') {
	(my $k = $pkg) =~ s!::!/!g ;
	(my $p = $INC{$k.'.pm'}) =~ s:\.pm\z:: ;
	my $dir = IO::Dir->new($p) || die "opendir($p) failed: $!";
	while(my $f = $dir->read()) { if($f =~ /^(.*)\.pm\z/) {
	    my $name = $1;
	    if('1' ne hvn '-', \%EXCLUDE_PAGES, @FCGI::AutoPage::Folder::import_path, $name) {
		&load_page($pkg, $name);
	    }
	} }
	$dir->close() || warn "closedir($p) failed: $!";
    }
    else {
	foreach my $m (@_) { &load_page($pkg, $m); }
    }
}

sub load_page {
    my $pkg = shift;
    my $page = shift;
    eval "package $pkg; use $pkg\::$page;";
    if(my $err = $@) { warn "use $pkg\::$page;\n\$pkg=$pkg, \$page=$page\n"; die $err; }
}

sub path_switch {
    my $self = shift;
    my $uri = shift;
    my($name,$rest) = (split '/', $uri, 3)[1,2];
    foreach my $pkg (@pages) {
	if(my $page = $pages{$pkg}{$name}) { return $page->new($self, $rest)->print_page(); }
    }
    return;
}

sub path_switch_root {
    my $self = shift;
    my $root = shift;
    my $uri = shift;
    my($name,$rest) = (split '/', $uri, 3)[1,2];
    if(my $page = $pages{$root}{$name}) { return $page->new($self, $rest)->print_page(); }
    return;
}
