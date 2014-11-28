package PageGen::HTML;

use strict;
use English;
use PageGen::Utils qw(&escape_v);
use Reshu::Utils qw(&n &hv &d &dw);
use DbEdit::Request;
use base qw(PageGen::Generic);

use constant USER_URI => 1;
use constant DEFAULT_CHARSET => 'utf-8';

1;

sub print {
    my $self = shift;
    if(!@_) { ; }
    elsif(ref($_[0]) eq 'HASH') {
	my $attr = shift;
	my @end;
	# Параметры тега насыщенности: { bold=>0 или 1 }
	if (defined($attr->{bold})) { $self->{out}->print('<b>'); push @end, '</b>'; }
	# Параметры тега наклона: { italic=>0 или 1 }
	if (defined($attr->{italic})) { $self->{out}->print('<i>'); push @end, '</i>'; }
	# Параметры тега размера шрифта: { size=>число } и цвета { color => 'red' или '#FF00FF' или '0,127,255'}
	if (defined($attr->{size}) or defined($attr->{color})) {
	    $self->{out}->print('<font',
		(defined($attr->{size}) ? (' size="'.$attr->{size}.'"') : ()),
		(defined($attr->{color}) ? (' color="'.&color_name($attr->{color}).'"') : ()),
		'>');
	    push @end, '</font>';
	}
	$self->{out}->print(@_, reverse @end);
    }
    else { $self->{out}->print(@_); }
}

sub printe {
    my $self = shift;
    $self->{out}->print(map((defined $_ ? (&escape_html($_)) : ()), @_));
}

# Перенесено в Generic
# sub c { #+++ Реализовать данный функционал в print ?
#     my $self = shift;
#     foreach my $content (@_) {
# 	if(!$self->call($content)) { $self->{out}->print($content); }
#     }
# }

sub ce {
    my $self = shift;
    foreach my $content (@_) {
	if(!$self->call($content)) { $self->{out}->print(&escape_html($content)); }
    }
}

sub join {
    my $self = shift;
    my $sep = shift;
    my $first = 1;
    foreach my $content (@_) {
	if($first) { undef $first; }
	elsif(!$self->call($sep)) { $self->{out}->print($sep); }
	if(!$self->call($content)) { $self->{out}->print($content); }
    }
}

sub joine {
    my $self = shift;
    my $sep = shift;
    my $first = 1;
    foreach my $content (@_) {
	if($first) { undef $first; }
	elsif(!$self->call($sep)) { $self->{out}->print(&escape_html($sep)); }
	if(!$self->call($content)) { $self->{out}->print(&escape_html($content)); }
    }
}

# Перенесено в Generic
# sub call {
#     my $self = shift;
#     my $content = shift;
#     # if(!defined($content) || $content eq '') { return 1; }
#     if(!defined($content)) { return 1; }
#     #+++ В Заказ-Наряде используется преобразование пустой строки в &nbsp;
#     elsif((my $r = ref $content) eq 'CODE') { $content->(); return 1; }
#     elsif($r eq 'ARRAY' && @$content && (my $code = $self->can($content->[0]))) {
# 	$code->($self, @{$content}[1 .. $#$content]);
# 	return 1;
#     }
#     elsif(HTML_DEBUG && $r) { require FPIC::Debdata; $self->{out}->print(&FPIC::Debdata::debdata_html($content)); return 1; }
#     #+++ if(ref($content->[0]) eq 'CODE') { ... }
#     else { return; }
# }

sub meta_charset {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    if(!defined($attr->{charset})) { $attr->{charset} = DEFAULT_CHARSET; }
    $self->{out}->print('<meta http-equiv="Content-Type" content="text/html; charset=', $attr->{charset}, "\" />\n");
}

sub doc {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    my @content = @_;
#     if (defined($attr->{cellpadding}))
# 	{$attr->{cellpadding} = int($attr->{cellpadding} / 0.2640625)}
# 	else
# 	{$attr->{cellpadding} = 8} # = 7.573964497041420118
    local $self->{doc_attr} = $attr;
    if(!defined($attr->{no_cache}) || $attr->{no_cache}) { $self->{out}->no_cache(1); }
    if(!defined($attr->{charset})) { $attr->{charset} = DEFAULT_CHARSET; }
    my $caption = &n($attr->{caption}, $self->{page_caption});
    my $title = &n($attr->{title}, $self->{page_title}, $caption);
    $self->{out}->send_http_header('text/html; charset='.$attr->{charset});
    $self->{out}->print("<html>\n<head>\n",
	'<meta http-equiv="Content-Type" content="text/html; charset=', $attr->{charset}, "\" />\n",
	(defined($title) ? ('<title>', &escape_html($title), "</title>\n") : ()),
	($attr->{js} ? (map "<SCRIPT LANGUAGE=JavaScript SRC=\"$_\"></SCRIPT>\n",
		map &escape_html($_ =~ /\.js$/ ? $_ : $_.'_'.$self->{out}->{bp}->{name}.'.js'), @{$attr->{js}}) : ()),
	($attr->{css_links} ? (map "<LINK REL=StyleSheet HREF=\"$_\" />\n", map &escape_html($_), @{$attr->{css_links}}) : ()));
    $self->css($attr->{css} || { defaults => 1 });
    if($attr->{link}) { $self->link(@{ $attr->{link} }); }
    $self->{out}->print("</head>\n<body");
    if(my $v = $attr->{body_onactivate}) {
	$self->{out}->print(' onactivate="', &escape_html($v), '"');
	#+++ А как с noescape ???
    }
    if(my $v = $attr->{body_onload}) {
	$self->{out}->print(' onload="', &escape_html($v), '"');
    }
    if(my $v = $attr->{body_onbeforeunload}) {
	$self->{out}->print(' onbeforeunload="', &escape_html($v), '"');
    }
    $self->{out}->print(">\n");
    if(defined($caption)) { $self->h1($caption); }
    foreach my $content (@content) {
	if($self->call($content)) { ; }
	elsif ($attr->{noescape}) { $self->{out}->print($content); }
	else { $self->{out}->print(&escape_html($content)); }
    }
    $self->{out}->print('</body></html>
');
    return HTTP_OK;
}

sub css {
    my $self = shift;
    my $css = { %{ shift(@_) } };
    #+++
    if(my $files = delete $css->{files}) { foreach my $file (@$files) {
	$self->link(type => 'text/css', rel => 'stylesheet', href => $file);
    } }
    return unless %$css;
    $self->{out}->print("<style type=\"text/css\"><!--\n");
    if($css->{defaults}) {
	$self->{out}->print("table { border-collapse: collapse; }\n");
	delete $css->{defaults};
    }
    if($css->{media_print}) {
	$self->{out}->print(
'@media print { .edit {display: none; visibility: hidden;} a {color:black; text-decoration:none} }
@media screen, projection { .print {display: none; visibility: hidden;} }
');
	if(ref $css->{media_print} eq 'HASH'){
	    foreach my $k (sort keys %{$css->{media_print}}) {
		my $cl = $css->{media_print}->{$k};
		if(exists $cl->{print}){
		    my $v = $cl->{print};
		    $self->{out}->print('@media print { .', $k, ' { ',
			ref($v) eq 'HASH' ?
			    (map((&style_attr_name($_), ': ', $v->{$_}, '; '), sort keys %$v)) :
			    ($v, ' '), "} }\n");
		}
		if(exists $cl->{screen}){
		    my $v = $cl->{screen};
		    $self->{out}->print('@media screen, projection { .', $k, ' { ',
			ref($v) eq 'HASH' ?
			    (map((&style_attr_name($_), ': ', $v->{$_}, '; '), sort keys %$v)) :
			    ($v, ' '), "} }\n");
		}
	    }
	}
	delete $css->{media_print};
    }
    if(my $raw = delete $css->{raw}) { $self->{out}->print($raw); }
    foreach my $k (sort keys %$css) {
	my $v = $css->{$k};
	$self->{out}->print($k, ' { ', ref($v) eq 'HASH' ? (map((&style_attr_name($_), ': ', $v->{$_}, '; '),
		sort keys %$v)) : ($v, ' '), "}\n");
    }
    $self->{out}->print("--></style>\n");
}

sub link {
    my $self = shift;
    $self->{out}->print("<LINK");
    while(@_) {
	my $name = shift;
	my $value = shift;
	$self->{out}->print(' ', &escape_html($name), '="', &escape_html($value), '"');
    }
    $self->{out}->print(" />");
}

# sub h1 {
#     my $self = shift;
#     my $attr = ref($_[0]) eq 'HASH' ? shift : {};
#     local $attr->{tag} = 'h1';
#     &p($self, $attr, @_);
# }

# sub p {
#     my $self = shift;
#     my $attr = ref($_[0]) eq 'HASH' ? shift : {};
#     my @content = @_;
# #     my $content = shift;
# 
#     my $tag = &n($attr->{tag}, 'p');
#     my $start_p = "<$tag";
#     my $end_p = "</$tag>\n";
# 
#     # Параметры тега "красной" строки: { indent=> кол-во мм}
#     if (defined($attr->{indent})) {$start_p .= ' style="text-indent:'.$attr->{indent}.'mm"'};
#     # Параметры тега выравнивания: { align=>'l', align=>'c', align=>'r', align=>'j' }
#     if (defined($attr->{align})) {
# 	if ($attr->{align} eq 'l') { $start_p .= ' align="left">' }
# 	elsif ($attr->{align} eq 'c') { $start_p .= ' align="center">' }
# 	elsif ($attr->{align} eq 'r') { $start_p .= ' align="right">' }
# 	elsif ($attr->{align} eq 'j') { $start_p .= ' align="justify">' }
#     }
#     $start_p .= '>';
#     # Параметры тега насыщенности: { bold=>0 или 1 }
#     if (defined($attr->{bold})) {$start_p .= '<b>'; $end_p = '</b>'.$end_p};
#     # Параметры тега наклона: { italic=>0 или 1 }
#     if (defined($attr->{italic})) {$start_p .= '<i>'; $end_p = '</i>'.$end_p};
#     # Параметры тега подчеркивания: { u=>0 или 1 }
#     if (defined($attr->{u})) {$start_p .= '<u>'; $end_p = '</u>'.$end_p};
#     # Параметры тега размера шрифта: { size=>число } и цвета { color => 'red' или '#FF00FF' или '0,127,255'}
#     if (defined($attr->{size}) or defined($attr->{color})) {
# 	$start_p .= '<font';
# 	if (defined($attr->{size})) {$start_p .= ' size="'.$attr->{size}.'"'};
# 	if (defined($attr->{color})) {$start_p .= ' color="'.&color_name($attr->{color}).'"'};
# 	$start_p .= '>';
# 	$end_p = '</font>'.$end_p;
#     };
# 
#     $self->{out}->print($start_p);
#     foreach my $content (@content) {
# 	if($self->call($content)) { ; }
# 	elsif ($attr->{noescape}) { $self->{out}->print($content ? $content : '&nbsp;'); }
# 	else { $self->printe($content); }
#     }
#     $self->{out}->print($end_p);
# }

sub tag_with_text {
    my $tag = shift;
    my $nl = shift;
    my $self = shift;
#     warn &DbEdit::Utils::p(), 'sub=', &d((caller 0)[3]), "\n";
    $self->{out}->print('<', $tag);
    if(@_ && ref($_[0]) eq 'HASH') { $self->style_attr(shift, $tag); }
    $self->{out}->print('>');
    $self->ce(@_);
    $self->{out}->print('</', $tag, '>', ($nl ? ("\n") : ()));
}

sub tag_with_childs {
    my $tag = shift;
    my $nl = shift;
    my $child = shift;
    my $self = shift;
    my $nochild;
    my $d = $self->delay_push;
    eval {
	$self->{out}->print('<', $tag);
	if(@_ && ref($_[0]) eq 'HASH') {
	    my $tattr = shift;
	    $self->style_attr($tattr, $tag);
	    if(defined($tattr->{child}) && !$tattr->{child}) { $nochild = 1; }
	}
	$self->{out}->print('>');
	$self->delay_print_next;
	while(@_) {
	    my $attr = @_ && ref($_[0]) eq 'HASH' ? shift : undef;
	    my $content = shift;
	    if(($nochild && (!$attr || !$attr->{child})) || ($attr && defined($attr->{child}) && !$attr->{child})) {
		if(!$self->call($content)) { $self->{out}->print(&escape_html($content)); }
	    }
	    else { $child->($self, $attr ? $attr : (), $content); }
	}
    };
    my $err = $EVAL_ERROR;
    $self->delay_pop($d);
    if($err) { die $err; }
    if(!$d->{buf}) { $self->{out}->print('</', $tag, '>', ($nl ? ("\n") : ())); }
}

sub tag_without_text {
    my $tag = shift;
    my $self = shift;
#     warn &DbEdit::Utils::p(), 'sub=', &d((caller 0)[3]), "\n";
    $self->{out}->print('<', $tag);
    if(@_ && ref($_[0]) eq 'HASH') { $self->style_attr(shift, $tag); }
    $self->{out}->print(' />');
    if(@_) { my $a = [ @_ ]; warn &p(), 'too many args, tag=', &d($tag), ', extra args ', &d($a), "\n"; }
}

# sub div { &tag_with_text('div', @_); }
# sub span { &tag_with_text('span', @_); }
# sub a { &tag_with_text('a', @_); }

BEGIN {
    foreach my $tag (qw(p div h1 h2 h3 h4 pre li option)) { eval "sub $tag { &tag_with_text('$tag', 'nl', \@_); }"; }
    foreach my $tag (qw(span strong a kbd label textarea b i u sub sup)) { eval "sub $tag { &tag_with_text('$tag', 0, \@_); }"; }
    foreach my $tag (qw(input img)) { eval "sub $tag { &tag_without_text('$tag', \@_); }"; }
    foreach my $tag (qw(ol ul)) { eval "sub $tag { &tag_with_childs('$tag', 'nl', \\&li, \@_); }"; }
    foreach my $tag (qw(select)) { eval "sub $tag { &tag_with_childs('$tag', 'nl', \\&option, \@_); }"; }
    foreach my $tag (qw(nbsp laquo raquo)) { eval "sub $tag { \$_[0]->{out}->print('&$tag;'); }"; }
}

sub table {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? { %{ shift(@_) } } : {};
    my @content = @_;
#     # является ли таблица вложенной?
#     my $is_req = (exists($self->{table_attr})) ? 1 : 0;
#     # Устанавливаем границы:
#     #  	{ border=>0 } - без границ
#     #  	{ border=>1 } - все границы (по умолчанию)
#     #  	{ border=>2 } - только внутренние
#     if (!defined($attr->{border})) {$attr->{border} = $is_req ? 2 : 1};
#     # отступ от границ таблицы: { cellpadding=>число (в миллиметрах) (по умолчанию устанавливается отступ документа) }
#     if (defined($attr->{cellpadding})) {$attr->{cellpadding} = int($attr->{cellpadding} / 0.2640625)} # Размер пикселя на матрице жк 1280*1024
#     else {$attr->{cellpadding} = $self->{doc_attr}->{cellpadding}};
#     # Устанавливаем вертикальное выравнивание в таблице
#     if (!defined($attr->{valign})) {$attr->{valign} = 't'};
    my $parent_attr = $self->{table_attr};
    local $self->{table_attr} = $attr;
    if(my $d = $self->{doc_attr}->{table}) {
	foreach my $k (keys %$d) {
	    if(!defined $attr->{$k}) { $attr->{$k} = $d->{$k}; }
	}
    }
    if(!defined $attr->{border}) {
	$attr->{border} = defined($self->{doc_attr}->{table_border}) ? $self->{doc_attr}->{table_border} : 1;
    }
    ################################################ОТКРЫВАЮ ТЭГ ТАБЛИЦЫ###################################################
    my $cellpadding = exists($attr->{cellpadding}) ? $attr->{cellpadding} : $self->{doc_attr}->{table_cellpadding};
    my $width = exists($attr->{width}) ? $attr->{width} :
	exists($self->{doc_attr}->{table_width}) ? $self->{doc_attr}->{table_width} :
	'100'; #+++ % перенести в значение, нельзя их по уму добавлять везде без разбору
    $self->{out}->print('<table',
	($width ? (' width="'.$width.($width =~ /\d\z/ ? '%' : '').'"') : ()),
	(!defined($attr->{height}) ? () : (' height="'.$attr->{height}.'"')),
# 	($attr->{border} == 1 ? ' frame=border' : ''),
# 	($attr->{border} > 0 ? ' rules=all' : ''),
# 	' cellspacing=0 cellpadding=', $attr->{cellpadding},
	!$attr->{border} ? () : &hv($parent_attr, 'border') || $attr->{border} == 2 ? (' rules=all') : (' border'),
# 	' cellspacing=0',
# 	' cellpadding=0',
	);
    if(defined $cellpadding) { $self->{out}->print(' cellpadding="', $cellpadding, '"'); }
    if(!$attr->{border_collapse} &&
		&n($attr->{need_table_style_border_collapse}, $self->{attr}->{need_table_style_border_collapse})) {
	$attr->{border_collapse} = 'collapse';
    }
    {   local @{$attr}{qw(width)};
	$self->style_attr($attr);
    }
    $self->{out}->print(">\n");
    ################################################СОЗДАЮ СТОЛБЦЫ#########################################################
    if ($attr->{col}) {
	$self->{out}->print("<colgroup>\n");
	foreach my $col (@{$attr->{col}}) {
	    $self->{out}->print("\t<col");
	    if(my $v = $col->{width}) { $self->{out}->print(" width=\"", $v, ($v =~ /\d\z/ ? '%' : ''), '"'); }
	    $self->{out}->print(" />\n");
	};
	$self->{out}->print("</colgroup>\n");
    }
    ################################################ОТКРЫВАЮ ТЭГ ТЕЛА ТАБЛИЦЫ##############################################
    my $tbody;
    my $valign = $attr->{valign} || $self->{doc_attr}->{table_valign};
    my $halign = $attr->{halign} || $self->{doc_attr}->{table_halign} || $attr->{align} || $self->{doc_attr}->{table_align};
    if($valign || $halign) {
	$tbody = 1;
	$self->{out}->print('<tbody',
		!$valign ? () :
		$valign eq 'top' || $valign eq 't' ? (' valign=top') :
		$valign eq 'c' ? (' valign=middle') :
		$valign eq 'b' ? (' valign=bottom') :
		(),
		!$halign ? () :
		$halign eq 'l' || $halign eq 'left' ? (' align=left') :
		$halign eq 'c' || $halign eq 'center' ? (' align=center') :
		$halign eq 'r' || $halign eq 'right' ? (' align=right') :
		$halign eq 'j' || $halign eq 'justify' ? (' align=justify') : (),
		">\n");
    }
    ################################################ВЫВОД ДАННЫХ###########################################################
    foreach my $content (@content) {
	if($self->call($content)) { ; }
	else { $self->{out}->print($content); }
    }
    if($tbody) { $self->{out}->print("</tbody>"); }
    $self->{out}->print("</table>\n");
}

sub tr {
    my $self = shift;
    local $self->{row_attr} = ref($_[0]) eq 'HASH' ? shift : {};
    # текущий столбец для определения ширины последнего столбца и определения выравнивания в столбце
    $self->{row_attr}->{cur_col} = 0;
#     $self->{out}->print("\t<tr>");
#     while(@_) {
# 	if(ref($_[0]) eq 'HASH') { $self->td(shift, shift); }
# 	else { $self->td(shift); }
#     }
#     $self->{out}->print("</tr>\n");
    &tag_with_childs('tr', 'nl', \&td, $self, $self->{row_attr}, @_);
}

sub trs {
    my $self = shift;
    local $self->{row_attr} = ref($_[0]) eq 'HASH' ? shift : {};
    # текущий столбец для определения ширины последнего столбца и определения выравнивания в столбце
    $self->{row_attr}->{cur_col} = 0;
    $self->{out}->print("\t<tr>");
    while(@_) {
	if(ref($_[0]) eq 'HASH') { $self->td(shift, shift); }
	else {
	    my $content = shift;
	    if($self->call($content)) { ; }
	    else { $self->td($content); }
	}
    }
    $self->{out}->print("</tr>\n");
}

sub td_attr {
    my $self = shift;
    my $td_attr = shift;
    my $name = shift;
    my $no_table_attr = shift;
    if(ref($name) eq 'ARRAY') {
	foreach my $n (@$name) {
	    if(defined(my $r = $self->td_attr($td_attr, $n, $no_table_attr))) { return $r; }
	}
	return;
    }
    else {
	return &n($td_attr->{$name},
		$self->{table_attr}->{col}->[$self->{row_attr}->{cur_col}]->{$name},
		$self->{row_attr}->{$name}, ($no_table_attr ? () : ($self->{table_attr}->{$name})));
    }
}

sub td {
    my $self = shift;
    my $td_attr = ref($_[0]) eq 'HASH' ? shift : {};
    my $content = shift;

    my $tag = &td_attr($self, $td_attr, 'th') ? 'th' : 'td';
    $self->{out}->print('<'.$tag);
    # применяю параметры ячейки ------------------------------------------------------------------------------------------------------------------
#     # Ширина столбца
#     if(defined $td_attr->{width}) { $self->{out}->print(' width="'.&escape_html($td_attr->{width}).'"'); }
# задается через style в &attr()
    # Объединение по вертикали
    if(defined $td_attr->{rowspan}) { $self->{out}->print(' rowspan="'.&escape_html($td_attr->{rowspan}).'"'); }
    # Объединение по горизонтали
    if(defined $td_attr->{colspan}) { $self->{out}->print(' colspan="'.&escape_html($td_attr->{colspan}).'"'); }
    # Запрет переноса
    if($td_attr->{nowrap} || $self->{table_attr}->{col}->[$self->{row_attr}->{cur_col}]->{nowrap}) {
	$self->{out}->print(' nowrap'); }
    # Параметры тега "красной" строки: { indent=> кол-во мм}
    if(defined(my $indent = $self->td_attr($td_attr, 'indent'))) {
	$self->{out}->print(' style="text-indent:'.$indent.'mm"');
    }
    # Выравнивание
    $td_attr->{align} = $self->td_attr($td_attr, ['align', 'halign'], 'no_table_attr');
    if(defined(my $valign = $self->td_attr($td_attr, 'valign', 'no_table_attr'))) {
	$self->{out}->print(' valign="', &mapchar($valign, qw(top bottom), [qw(middle c)]), '"');
    }
    $self->style_attr($td_attr);
    $self->{out}->print('>');

#     # Перенесено в style_attr
#     my $s_s = '';
#     my $s_e = '</'.$tag.'>';
#     # Параметры тега размера шрифта: { size=>число } и цвета { color => 'red' или '#FF00FF' или '0,127,255'}
#     if(defined(my $size = $self->td_attr($td_attr, 'size')) or defined(my $color = $self->td_attr($td_attr, 'color'))) {
#         $s_s .= '<font';
#         if (defined($size)) {$s_s .= ' size="'.$size.'"'};
#         if (defined($color)) {$s_s .= ' color="'.&color_name($color).'"'};
#         $s_s .= '>';
#         $s_e = '</font>'.$s_e;
#     };
#     # Параметры тега насыщенности: { bold=>0 или 1 }
#     if (defined($self->td_attr($td_attr, 'bold')) && $self->td_attr($td_attr, 'bold') == 1) { $s_s .= '<b>'; $s_e = '</b>'.$s_e };
#     # Параметры тега подчеркивания: { u=>0 или 1 }
#     if (defined($self->td_attr($td_attr, 'u')) && $self->td_attr($td_attr, 'u') == 1) { $s_s .= '<u>'; $s_e = '</u>'.$s_e };
#     # Параметры тега курсива: { italic=>0 или 1 }
#     if (defined $self->td_attr($td_attr, 'italic')) { $s_s .= '<i>'; $s_e = '</i>'.$s_e };
#     # --------------------------------------------------------------------------------------------------------------------------------------------
#     $self->{out}->print($s_s);

    if(!defined($content) || $content eq '') { $self->{out}->print('&nbsp;') }
    elsif($self->call($content)) { ; }
    elsif($self->td_attr($td_attr, 'noescape')) { $self->{out}->print($content); }
    else { $self->printe($content); }
    $self->{out}->print('</', $tag, '>');
    $self->{row_attr}->{cur_col}++;
}

sub no {
    my $self = shift;
    $self->{out}->print('&#8470;');
}

sub br {
    my $self = shift;
    $self->{out}->print("<br />\n");
}

# sub nbsp {
#     my $self = shift;
#     $self->{out}->print('&nbsp;');
# }

sub fmt_date {
    my $self = shift;
    my $date = shift;
    if($date !~ /^(\d{2,4})-(\d{2})-(\d{2})(?: \d\d:\d\d:\d\d)?$/) { die; }
    my($y,$m,$d) = ($1,$2,$3);
    $self->{out}->print("&#171;$d&#187; $PageGen::Generic::MonthNames[$m] $y г.");
}

sub escape {my $self = shift; return &escape_html(shift);}

sub form {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
#     $self->{out}->print('<form', map((' ',$_,'="',$attr->{$_},'"'), keys %{$attr}), '>');
#     foreach my $content (@_) {
# 	if($self->call($content)) { ; }
# 	else { $self->{out}->print($content); }
#     }
#     $self->{out}->print('</form>');
    my $form = {};
    foreach my $item (@_) { $self->scan_form($form, $item); }
    if($form->{radio}) { foreach my $g (values %{$form->{radio}}) { if($g->{first}) { $g->{first}->{checked} = 1; } } }
    &tag_with_text('form', 0, $self, $attr, @_);
    if($attr->{setfocus}) {
	$self->{out}->print('
<script language=JavaScript><!--
document.'.$attr->{name}.'.'.$attr->{setfocus}.'.focus();
//--></script>
');
    }
}

sub scan_form {
    my $self = shift;
    my $form = shift;
    my $content = shift;
    if(defined($content) && ref($content) eq 'ARRAY' && @$content) {
	if($content->[0] eq 'input') { if(ref(my $attr = $content->[1]) eq 'HASH') {
	    if($attr->{type} eq 'radio') {
		if(!$attr->{name}) { warn; }
		else {
		    my $g = $form->{radio}->{$attr->{name}};
		    if(!$g) {
			$form->{radio}->{$attr->{name}} = { first => defined($attr->{checked}) ? undef : $attr };
		    }
		    elsif($g->{first} && defined($attr->{checked})) { undef $g->{first}; }
		}
	    }
	} }
	elsif($self->can($content->[0])) {
	    foreach my $item (@{$content}[1..$#$content]) { $self->scan_form($form, $item); }
	}
    }
}

# sub input {
#     my $self = shift;
#     my %attr = @_;
#     $self->{out}->print('<input',map(' '.$_.'="'.$attr{$_}.'"', keys %attr),'>');
# }

BEGIN { *tde = *td_empty; }
sub td_empty {
    my $self = shift;
    $self->{out}->print('&nbsp;');
}

sub href {
    my $self = shift;
    my $ref = shift;
    my $text = shift;
    $self->{out}->print('<a href="', $ref, '">', &escape_html($text), '</a>');
}

sub color_name{
    my $color = shift;
    if ($color eq 'black'
        or $color eq 'red'
        or $color eq 'blue'
        or $color eq 'purple'
        or $color eq 'white'
        or $color eq 'green'
        or $color eq 'aqua'
        or $color eq 'yellow'
        or $color eq 'silver'
        or $color eq 'gray'
        or $color eq 'maroon'
        or $color eq 'fuchsia'
        or $color eq 'lime'
        or $color eq 'olive'
        or $color eq 'navy'
        or $color eq 'teal') {return $color;}
    elsif ($color =~ m/^#?[\dABCDEF]{6}$/i) {
        if ($color !~ m/^#/) {$color = '#'.$color}
        return uc($color);
    }
    elsif ($color =~ m/^\d{1,3},\s?\d{1,3},\s?\d{1,3}$/) {
        my @rgb = $color =~ m/(\d+)/g;
        foreach (@rgb) {if($_ > 255) {die "Неправильный компонент RGB: ", &d($_), "\n";}}
        return '#'.CORE::join('', map sprintf("%02X", $_), @rgb);
    }
    elsif (ref($color) eq 'ARRAY' && @$color == 3) {
        foreach (@$color) {if($_ !~ /^\d+$/ || $_ > 255) {die "Неправильный компонент RGB: ", &d($_), "\n";} }
        return '#'.CORE::join('', map sprintf("%02X", $_), @$color);
    }
    else { die 'Неправильно указан цвет: ', &d($color), "\n"; }
}

sub style_attr {
    my $self = shift;
    my $attr = shift;
    my $caller_sub = shift || (split /::/, (caller 1)[3])[-1];
    my $prn;
    my $common_text = 1;
    my $sa = sub {
	my $name = shift;
	if(defined(my $v = $attr->{$name})) {
	    (my $sname = $name) =~ s/_/-/g;
	    if(!$prn) { $self->{out}->print(' style="'); $prn = 1 }
	    $self->{out}->print($sname, ':', ref($v) eq 'ARRAY' && @$v == 2 && $v->[0] eq 'noescape' ?
		($v->[1]) : (&escape_html($v)), ';');
	}
	return;
    };
    my $sta = sub {
	my $name = shift;
	if(my $v = $attr->{style}->{$name}) {
	    (my $sname = $name) =~ s/_/-/g;
	    if(!$prn) { $self->{out}->print(' style="'); $prn = 1 }
	    $self->{out}->print($sname, ':', ref($v) eq 'ARRAY' && @$v == 2 && $v->[0] eq 'noescape' ?
		($v->[1]) : (&escape_html($v)), ';');
	}
	return;
    };
    my $ssa = sub { # static, noescape
	my $name = shift;
	my $v = shift;
	if(!$prn) { $self->{out}->print(' style="'); $prn = 1 }
	$self->{out}->print($name, ':', $v, ';');
	return;
    };
    my $sse = sub { # static, escape
	my $name = shift;
	my $v = shift;
	if(!$prn) { $self->{out}->print(' style="'); $prn = 1 }
	$self->{out}->print($name, ':', &escape_html($v), ';');
	return;
    };
    my $at = sub {
	my $k = shift;
	my $v = $attr->{$k};
	# $k =~ s/_/-/g;
	if(defined $v) { $self->{out}->print(' ', $k, '='); $self->val_str($v, '"', '"'); }
    };
    my $ates = sub {
	my $k = shift;
	my $v = $attr->{$k};
	# $k =~ s/_/-/g;
	if(defined($v) && $v ne '') { $self->{out}->print(' ', $k, '='); $self->val_str($v, '"', '"'); }
    };
    my $atv = sub {
	my $k = shift;
	my $v = $attr->{$k};
	# $k =~ s/_/-/g;
	if($v) { $self->{out}->print(' ', $k, '='); $self->val_str($v, '"', '"'); }
    };

    foreach my $k (qw(id name class onload onclick onmouseover onmouseout)) { $at->($k); }

    if($caller_sub eq 'a') {
	if(my $a = $attr->{href_args}) {
	    $self->{out}->print(' href="');
	    $self->href_args($attr->{href}, @$a);
	    $self->{out}->print('"');
	    foreach my $k (qw(target)) { $at->($k); }
	}
	elsif(my $jref = $attr->{jref}) {
	    $self->{out}->print(' href="javascript:', &escape_html($jref), '"');
	}
	else { foreach my $k (qw(href target name)) { $at->($k); } }
    }
    elsif($caller_sub eq 'input') {
	foreach my $k (qw(type maxlength tabindex autocomplete onkeyup onkeypress onkeydown onblur onchange onpaste)) { $at->($k); }
	foreach my $k (qw(checked disabled readonly)) { $atv->($k); } # checked => 0 мы можем использовать для выключения механизма добавления checked первому radio
	# foreach my $k (qw(value)) { $ates->($k); }
	# Для value использовать ates нельзя. Например для type=radio отсутствие value приводи к значению on.
	foreach my $k (qw(value)) { $at->($k); }
	undef $common_text;
    }
    elsif($caller_sub eq 'textarea') {
	foreach my $k (qw(rows cols maxlength tabindex autocomplete onkeyup onkeypress onkeydown onblur onchange onpaste)) { $at->($k); }
	foreach my $k (qw(disabled readonly)) { $atv->($k); }
	undef $common_text;
    }
    elsif($caller_sub eq 'select') {
	foreach my $k (qw(tabindex onkeyup onkeypress onkeydown onblur onchange onpaste)) { $at->($k); }
	foreach my $k (qw(disabled readonly)) { $atv->($k); }
	undef $common_text;
    }
    elsif($caller_sub eq 'option') { foreach my $k (qw(value)) { $at->($k); } }
    elsif($caller_sub eq 'label') { foreach my $k (qw(for)) { $at->($k); } }
    elsif($caller_sub eq 'form') { foreach my $k (qw(action method target onsubmit)) { $at->($k); } undef $common_text; }
    elsif($caller_sub eq 'td') { map $sa->($_), qw(border_top border_bottom border_left border_right); }
    elsif($caller_sub eq 'table') {
	foreach my $k (qw(border_collapse)) { $sa->($k); }
	undef $common_text;
    }
    # Для tr оставлен $common_text, поскольку все эти свойства унаследуются td
    elsif($caller_sub eq 'div') { foreach my $k (qw(border)) { $sa->($k); } }
    elsif($caller_sub eq 'p') {
	if(defined(my $v = $attr->{indent})) {
	    if($v =~ /\A\d+\z/) { $v .= 'mm'; }
	    $sse->('text-indent', $v);
	}
    }
    elsif($caller_sub eq 'img') {
	foreach my $k (qw(src alt)) { $at->($k); }
	undef $common_text;
    }

    if($attr->{custom}) {
	my @a = @{$attr->{custom}};
	while(@a) {
	    my $k = shift @a;
	    my $v = shift @a;
	    $self->{out}->print(' ', &escape_html($k), '=', ref($v) eq 'ARRAY' && @$v == 2 && $v->[0] eq 'noescape' ?
		($v->[1]) : ('"', &escape_html($v), '"'));
	}
    }

    if($common_text) {
	foreach my $k (qw(font_size text_decoration)) { $sa->($k); }
	if(defined(my $v = $attr->{size})) { $sse->('font-size', $v); }
	if(defined(my $align = $attr->{align})) { $ssa->('text-align', &mapchar($align, qw(left center right justify))); }
	if($attr->{bold}) { $ssa->(qw(font-weight bold)); }
	if($attr->{italic}) { $ssa->(qw(font-style italic)); }
	if($attr->{underline} || $attr->{u}) { $ssa->(qw(text-decoration underline)); }
	if($attr->{nowrap}) { $ssa->(qw(white-space nowrap)); }
	foreach my $k (qw(color background-color)) { if($attr->{$k}) { $ssa->($k => &color_name($attr->{$k})); } }
	if($attr->{background_color}) { $ssa->('background-color' => &color_name($attr->{background_color})); }
	if($attr->{bgcolor}) { $ssa->('background-color' => &color_name($attr->{bgcolor})); }
    }

    foreach my $k (qw(display position top right left margin margin_left margin-left padding padding_top padding-top padding_left padding-left padding_right padding-right width height cursor z_index z-index text_align text-align)) { $sa->($k); }

    if(ref($attr->{style}) eq 'HASH') { foreach my $k (qw(width float)) { $sta->($k); } }

    if($prn) { $self->{out}->print('"'); }
}

sub style_attr_name {
    my $name = shift;
    $name =~ s/_/-/g;
    return $name;
}

sub doc_back {
    my $self = shift;
    $self->doc(['js', 'history.back();']);
    return HTTP_OK;
}

sub js {
    my $self = shift;
    my $attr = @_ && ref($_[0]) eq 'HASH' ? shift : {};
    $self->{out}->print("<SCRIPT LANGUAGE=JavaScript".($attr->{src} ?
	' SRC="'.($attr->{src} =~ /\.js$/ ? $attr->{src} : $attr->{src}.'_'.$self->{out}->{bp}->{name}.'.js').'"' : '').">");
    if(@_) {
	$self->{out}->print("\n<!--\n");
	$self->c(@_);
	$self->{out}->print("\n//-->\n");
    }
    $self->{out}->print("</SCRIPT>\n");
}

sub script {
    my $self = shift;
    $self->{out}->print(map +("<SCRIPT LANGUAGE=JavaScript SRC=\"", &escape_html($_), "\"></SCRIPT>\n"), @_);
}

sub foreach {
    my $self = shift;
    &DbEdit::Utils::foreach_call(@_);
}

sub mapchar {
    my $ch = shift;
    foreach my $v (@_) {
	if(ref($v) eq 'ARRAY') {
	    foreach my $vi (@$v) {
		if($ch eq $vi || $ch eq substr($vi, 0, 1)) { return $v->[0]; }
	    }
	}
	elsif($ch eq $v || $ch eq substr($v, 0, 1)) { return $v; }
    }
    die;
}

sub hr {
    my $self = shift;
    my $attr = { %{shift || {}} };
    $self->{out}->print('<hr ');
    if($attr->{size}) { $self->{out}->print(' size="',$attr->{size},'"'); delete $attr->{size}; }
    if($attr->{width}) { $self->{out}->print(' width="',$attr->{width},'"'); delete $attr->{width}; }
    if($attr->{color}) {
	$self->{out}->print(' color="',&color_name($attr->{color}),'"'); delete $attr->{color};
    } else {
	$self->{out}->print(' color="black"');
    }
    $self->style_attr($attr, 'hr');
    $self->{out}->print(">\n");
}

sub filling {
    my $self = shift;
    my $width = shift;
    my $text = shift;
    if($width !~ m/^\d+(?:mm|%)$/) { die 'Нарушен формат ширины.'; }
    my $valign_tr = $text ? '<tr><td align="center" style="font-size: 70%">'.&escape_html($text)."</td></tr>\n" : '';
# display:-moz-inline-stack; /*Нужно для Firefox*/
    $self->{out}->print(
	'<span style="display:-moz-inline-stack; display:inline-block;width:',$width,';vertical-align:top">',
	'<table width="100%" cellpadding="0" cellspacing="0">',
	'<tr><td style="border-bottom: 1px solid black">&nbsp;</td></tr>',
	$valign_tr,
	'</table></span>'
    );
}

sub debug {
    my $self = shift;
    my $v = shift;
    if(eval{require FPIC::Debdata;}) {
	if(@_) {
	    local %FPIC::Debdata::refs = ( map(((0+$_) => "HIDDEN $_"), @_) );
	    local %FPIC::Debdata::recurs = ();
	    $self->{out}->print(&FPIC::Debdata::encode_html($v), "\n");
	}
	else { $self->{out}->print(&FPIC::Debdata::debdata_html($v), "\n"); }
    }
    else { $self->{out}->print(&escape_html($v)); }
}

sub user_uri {
    my $self = shift;
    if(USER_URI) {
	our $user_name;
	if(!$user_name) { $user_name = getpwuid($UID); }
	return map { my $v = $_; $v =~ s!\A/!/~$user_name/!; $v; } @_;
    }
    else { return @_; }
}

sub box {
    my $self = shift;
    my $style = '';
    if(!@_) { return; }
    elsif(ref($_[0]) eq 'HASH') {
	my $attr = shift;
	if(defined $attr->{width}){
	    die 'Нарушен формат ширины.' if $attr->{width} !~ m/^\d+(mm|%)$/;
	    $style .= 'width: '.$attr->{width}.';';
	}
	if(defined $attr->{height}){
	    die 'Нарушен формат высоты.' if $attr->{height} !~ m/^\d+mm$/;
	    $style .= 'height: '.$attr->{height}.';';
	}
	if(defined $attr->{border}){
	    die 'Нарушен формат рамки.' if $attr->{border} !~ m/^\d+$/;
	    $style .= 'border: '.$attr->{border}.'px solid black;';
	}
	if(defined $attr->{valign}){
	    if($attr->{valign} eq 'top'){ $style .= 'vertical-align: top;'; }
	    elsif($attr->{valign} eq 'middle'){ $style .= 'vertical-align: middle;'; }
	    elsif($attr->{valign} eq 'bottom'){ $style .= 'vertical-align: bottom;'; }
	}
	if(defined $attr->{halign}){
	    if($attr->{halign} eq 'l'){ $style .= 'text-align: left;'; }
	    elsif($attr->{halign} eq 'c'){ $style .= 'text-align: center;'; }
	    elsif($attr->{halign} eq 'r'){ $style .= 'text-align: right;'; }
	}
	# display:-moz-inline-stack; /*Нужно для Firefox*/
    }
    $self->{out}->print('<span style="',$style,'display: -moz-inline-block; display: inline-block;">');
    foreach my $content (@_) {
	if(!$self->call($content)){ $self->{out}->print(&escape_html($content)); }
    }
    $self->{out}->print('</span>');
}

sub btns_ok_cancel {
    my $self = shift;
    $self->ce(
	['input', {qw(type submit value Ок)}], ' ',
	['input', {qw(type button value Отмена onclick), 'history.back();'}],
    );
}

sub href_args {
    my $self = shift;
#     my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    my $href = shift;
    if($href) { $self->ce($href); }
    if(@_ == 1) { $self->ce('?', &escape_v(shift)); }
    else {
	my $first = 1;
	while(@_) {
	    my $name = shift;
	    my $value = shift;
	    if(defined $value) {
		if($first) { undef $first; $self->{out}->print('?'); } else { $self->{out}->print('&'); }
		$self->ce(&escape_v($name), '=', &escape_v($value));
	    }
	}
	if($first && !$href) { $self->{out}->print('?'); }
    }
}

sub val_str {
    my $self = shift;
    my $value = shift;
    if(ref($value) eq 'ARRAY' && @$value == 2 && $value->[0] eq 'noescape') {
	$self->c($value->[1]);
    }
    else {
	if(@_) { $self->{out}->print($_[0]); }
	$self->ce($value);
	if(@_) { $self->{out}->print($_[1]); }
    }
}

sub var {
    my $self = shift;
    $self->ce($self->{web}->exp_slice(@_));
}

sub num {
    my $self = shift;
    my $n = ''.shift;
    if($n !~ /\A\d+\z/) { die 'Not number: ', &d($n); }
    my $r = substr($n, -3, 3);
    my $i = 3;
    while($i < length($n)) {
	$i += 3;
	$r = substr($n, -$i, 3).'&nbsp;'.$r;
    }
    $self->{out}->print($r);
}

BEGIN { *jss_quote = \&jss; }
sub jss {
    my $self = shift;
    my $value = shift;
    warn if @_;
    $self->{out}->print(&PageGen::Utils::jss_quote($value));
}

sub json_doc {
    my $self = shift;
    my $value = shift;
    warn if @_;
    $self->{out}->send_http_header('application/json; charset='.($self->{doc_attr}{charset} || DEFAULT_CHARSET));
    $self->json($value);
    return HTTP_OK;
}

sub json {
    my $self = shift;
    my $value = shift;
    warn if @_;
    unless(defined $value) { $self->{out}->print('null'); }
    elsif(ref($value) eq '') { $self->jss($value); }
    elsif(ref($value) eq 'HASH') {
	$self->{out}->print('{');
	my $first = 1;
	while(my($k,$v) = each %$value) {
	    if($first) { undef $first; } else { $self->{out}->print(','); }
	    $self->jss($k);
	    $self->{out}->print(':');
	    $self->json($v);
	}
	$self->{out}->print('}');
    }
    elsif(ref($value) eq 'ARRAY') {
	$self->{out}->print('[');
	my $first = 1;
	foreach my $v (@$value) {
	    if($first) { undef $first; } else { $self->{out}->print(','); }
	    $self->json($v);
	}
	$self->{out}->print(']');
    }
    elsif(my $c = eval { $value->can('print_script') }) { $c->($value, $self); }
    else { $self->jss($value); }
}

package PageGen::HTML::JsExp;
use DbEdit::PkgDefaults;
1;

sub new {
    my $class = shift;
    my $self = bless({ exp => [] }, ref($class) || $class);
    $self->add(@_) if @_;
    return $self;
}

sub clone {
    my $self = shift;
    return $self->new($self);
}

sub add {
    my $self = shift;
    foreach my $s (@_) {
	if(ref($s) eq 'ARRAY' && @$s == 2 && $s->[0] eq 'var') {
	    if(exists $self->{last}) {
		push @{$self->{exp}}, $self->{last};
		delete $self->{last};
	    }
	    push @{$self->{exp}}, $s;
	}
	elsif(ref($s) eq 'PageGen::HTML::JsExp') {
	    if(@{$s->{exp}}) {
		if(exists $self->{last}) {
		    if(ref $s->{exp}[0]) {
			push @{$self->{exp}}, $self->{last}, @{$s->{exp}};
		    }
		    else {
			my($first, @rest) = @{$s->{exp}};
			push @{$self->{exp}}, $self->{last}.$first, @rest;
		    }
		    if(exists $s->{last}) { $self->{last} = $s->{last}; }
		    else { delete $self->{last}; }
		}
		else {
		    push @{$self->{exp}}, @{$s->{exp}};
		    if(exists $s->{last}) { $self->{last} = $s->{last}; }
		}
	    }
	    elsif(exists $s->{last}) {
		$self->{last} .= $s->{last};
	    }
	}
	else { $self->{last} .= $s; }
    }
}

sub empty {
    my $self = shift;
    return !@{$self->{exp}} && !exists $self->{last};
}

sub get_script {
    my $self = shift;
    if(exists $self->{last}) {
	push @{$self->{exp}}, $self->{last};
	delete $self->{last};
    }
    return @{$self->{exp}} ? join '+', map ref($_) ? $_->[1] : &PageGen::Utils::jss_quote($_), @{$self->{exp}} : "''";
}

sub print_script {
    my $self = shift;
    my $r = shift;
    if(exists $self->{last}) {
	push @{$self->{exp}}, $self->{last};
	delete $self->{last};
    }
    my $first = 1;
    foreach my $s (@{$self->{exp}}) {
	if($first) { undef $first; } else { $r->{out}->print('+'); }
	if(ref $s) { $r->{out}->print($s->[1]); } else { $r->jss($s); }
    }
    if($first) { $r->{out}->print("''"); }
}

package PageGen::HTML::JsCode;
use DbEdit::PkgDefaults;
1;

sub new {
    my $class = shift;
    return bless({ code => [ @_ ] }, ref($class) || $class);
}

sub print_script {
    my $self = shift;
    my $r = shift;
    foreach my $content (@{$self->{code}}) {
	if(!$r->call($content)) { $r->{out}->print($content); }
    }
}
