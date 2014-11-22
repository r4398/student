package AutoPage::Page;
# Автор: Юрий Решетников <reshu@mail.ru>
use strict;
use warnings;
use bytes;
use Reshu::Utils;
1;

sub import {
    my $pkg = shift;
    my $callpkg = caller;
    $pkg->reg_page_uri($callpkg);
    return;
}

sub reg_page_uri {
    my $pkg = shift;
    my $callpkg = shift;
    if(defined(my $uri = $pkg->page_uri)) { $AutoPage::pages{$callpkg}{$uri} = $pkg; }
    # В некоторых случаях нам требуется стандартная страница, которая не будет отображаться по стандартным uri,
}

sub new {
    my $class = shift;
    my $self = {};
    $self->{web} = shift;
    $self->{uri} = shift;
    bless($self, $class);
}

sub page_js { qw(
    //ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js
    //ajax.googleapis.com/ajax/libs/jqueryui/1.11.2/jquery-ui.min.js
)}

sub page_css { qw(
    //ajax.googleapis.com/ajax/libs/jqueryui/1.11.2/themes/smoothness/jquery-ui.css
)}

sub page_path { return shift->page_uri; } # Переопределяется автоматически через sub import

sub page_addr {
    my $self = shift;
    my $attr = { @_ };
    if($attr->{full_uri}) {
	return $self->{web}->proto_host_port . join '/', $self->{web}->app_path, $self->page_path;
    }
    else { return join '/', $self->{web}->app_path, $self->page_path; }
}

sub menu_group { ; }
sub menu_attrs { ; }	# href args
sub menu_link {		# Для тех случаев, когда в меню не получается применить стандартный механизм формирование ссылки
    my $self = shift;
    ['a',{href => join('/', $self->page_path()), $self->menu_attrs()}, $self->page_title()];
}

sub check_access {}

sub pagegen_class { return; }

sub doc_attrs {
    my $page = shift;
    if($page->{attr}{media_print}) { return (css => {defaults => 1, media_print => 1}); }
    else { return; }
}

sub rr { my $self = shift; return $self->{web}->rr($self->pagegen_class); }

sub find_page {
    my $self = shift;
    return $self;
}

sub print_page {
    my $self = shift;
    my $rc;
    if($rc = $self->check_access) { return $rc; }
    else { return $self->full_page(); } #+++ Здесь можно добавить eval и вывод ошибки, но тогда надо сюда же добавлять откат баз данных
}

sub full_page {
    my $self = shift;
    $self->border_page(sub { $self->content_page });
}

sub border_page { $_[0]->{web}->border_page(@_); }
sub noborder_page { $_[0]->{web}->noborder_page(@_); }
sub content_page { ; }
sub page_title{ ; }

sub can_border_page {
# Нужен для возможности вызова forbidden, bad_args и т.п. из content_page
    my $self = shift;
    if($self->{in_border_page}) { $self->rr->ce(@_); return $self->{web}->HTTP_OK; }
    else { return $self->border_page(@_); }
}

sub not_implemented {
    my $self = shift;
    if(@_) { warnN 3, 'Not implemented, ', @_; } else { warn &p(1), 'Not implemented', "\n"; }
    return $self->can_border_page(['p', {qw(color red)}, 'Функция пока не реализована.']);
}

sub internal_error {
    my $self = shift;
    if(@_) { warnN 3, 'Error, ', @_; } else { warn &p(1), 'Error', "\n"; }
    return $self->can_border_page(['p', {qw(color red)}, 'Во время выполнения произошла ошибка. Обратитесь к администратору']);
}

sub forbidden {
    my $self = shift;
    if(@_) { warnN 3, 'FORBIDDEN, ', @_; } else { warnN 3, 'FORBIDDEN'; }
    return $self->can_border_page(['p', {qw(color red)}, 'Доступ запрещен']);
}

sub bad_args {
    my $self = shift;
    warn &Reshu::Utils::p(0,1), 'BAD_REQUEST, ', (@_ ? (@_, ', ') : ()), 'get=', &d($self->{web}{r}{get}), "\n";
    return $self->can_border_page(['p', {qw(color red)}, 'Неправильные параметры формы']);
}

sub hidden_fields {
    my $self = shift;
    my $p = $self->{web}->rr;
    while(@_) {
	my $field = shift;
	if(!$field) { last; }
	$p->input({ type => 'hidden', name => $field, value => $self->{post}{$field} });
    }
    while(@_) {
	my $field = shift;
	$p->input({ type => 'hidden', name => $field });
    }
}

sub args {
    my $page = shift;
    if($page->{args}) { return $page->{args}; }
    else { return $page->{args} = { @{$page->{web}{r}{get} || []} }; }
}

sub has_post {
    my $page = shift;
    return $page->{web}{r}{post} && 1;
}

sub post {
    my $page = shift;
    if($page->{post}) { return $page->{post}; }
    else { return $page->{post} = $page->{web}{var}{post} = { @{$page->{web}{r}{post} || []} }; }
}

sub get {
    my $page = shift;
    if($page->{get}) { return $page->{get}; }
    else { return $page->{get} = $page->{web}{var}{get} = { @{$page->{web}{r}{get} || []} }; }
}

sub web { return shift->{web}; }
sub script_name { return shift->{web}->env->{SCRIPT_NAME}; }
