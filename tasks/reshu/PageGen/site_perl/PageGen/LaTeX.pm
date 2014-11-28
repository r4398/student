package PageGen::LaTeX;
use strict;
use English;
use base qw(PageGen::Generic);

use Carp;
use File::Path;
use File::Temp;
use IO::File;
use Cwd;
use DbEdit::Utils qw(&n &image_suffix);

use constant PDFLATEX_PATH => '/usr/local/bin/pdflatex';
use constant SHOW_TEX_AFTER_ERROR => 1;

1;

sub print {
    my $self = shift;
    if(!@_) { ; }
    elsif(ref($_[0]) eq 'HASH') {
	my $attr = shift;
	my @end;
	# Параметры тега насыщенности: { bold=>0 или 1 }
	if (defined($attr->{bold})) { $self->{out}->print('{\bfseries '); unshift @end, '}'; }
	# Параметры тега наклона: { italic=>0 или 1 }
	if (defined($attr->{italic})) { $self->{out}->print('{\itshape '); unshift @end, '}'; }
	# Параметры тега подчеркивания: { u=>0 или 1 }
	if (defined($attr->{u})) { $self->{out}->print('\underline{'); unshift @end, '}'; }
	# Параметры тега размера шрифта: { size=>число }
	if (defined($attr->{size})) { $self->{out}->print(&fontsize($attr->{size})); unshift @end, '\normalfont{}'; }
	# Параметры тега цвета шрифта: { color=>'red' или '#FF00FF' }
	if (defined($attr->{color})) {$self->{out}->print(&color_name($attr->{color})); unshift @end, '}';}
	$self->{out}->print(@_, @end);
    }
    else { $self->{out}->print(@_); }
}

sub printe {
    my $self = shift;
    $self->{out}->print(map &escape_latex($_), @_);
}

sub c { #+++ Реализовать данный функционал в print ?
    my $self = shift;
    foreach my $content (@_) {
	if(!$self->call($content)) { $self->{out}->print($content); }
    }
}

sub ce {
    my $self = shift;
    foreach my $content (@_) {
	if(!$self->call($content)) { $self->{out}->print(&escape_latex($content)); }
    }
}

sub call {
    my $self = shift;
    my $content = shift;
    if((my $r = ref $content) eq 'CODE') { $content->(); return 1; }
    elsif($r eq 'ARRAY' && @$content && (my $code = $self->can($content->[0]))) {
	$code->($self, @{$content}[1 .. $#$content]);
	return 1;
    }
    else { return; }
}

sub doc {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    # $attr->{pdf} - вернуть ссылку на файл
    # $attr->{auto_del} - удалять файлы автоматически (0 - не удалять)
    # $attr->{textwidth} - ширина текста в mm
    # $attr->{pdf_attrs}->{document} - шапка документа до строки \begin{document}
    # $attr->{cellpadding} - боковые отступы внутри таблиц в mm
    # $attr->{pdf_href} - подключение пакета hyperref
    # $attr->{noescape} - не экранировать содержимое
    # $attr->{no_cache}
    # $attr->{dir} - рабочий каталог
    my @content = @_;
    # каталог
    $self->{http} = $self->{out};
    if($attr->{dir}){
	die if !-d $attr->{dir} || !-X $attr->{dir};
    }else{
	$attr->{dir} = &File::Temp::tempdir('tex.XXXXXXXX', TMPDIR => 1, CLEANUP => 1) || die;
    }
    push @{$self->{tmp_files}}, $attr->{dir}; # запоминаю созданный каталог
    my ($fh, $filename) = File::Temp::tempfile('out.XXXXXXXX', SUFFIX => '.tex', DIR => $attr->{dir});
    $filename =~ s/^$attr->{dir}(\/out.\S{8}).tex$/$1/ || die;
    $self->{out} = $fh;
    $self->{out}->print($attr->{pdf_attrs}->{document});

    if (defined($attr->{textwidth}))
	{$self->{out}->print("% ширина текста (210мм минус 20+10)\n\\textwidth=$attr->{textwidth}mm\n")}
	else
	{$self->{out}->print("% ширина текста (210мм минус 20+10)\n\\textwidth=180mm\n");
	$attr->{textwidth} = 180;};
    if (defined($attr->{cellpadding}))
	{$self->{out}->print("% ширина отступов внутри ячеек таблицы от границ\n\\tabcolsep=".$attr->{cellpadding}."mm\n")}
	else
	{$self->{out}->print("% ширина отступов внутри ячеек таблицы от границ\n\\tabcolsep=2mm\n");
	$attr->{cellpadding} = 2;};
    local $self->{doc_attr} = $attr;

    if (defined($attr->{pdf_href}))
	{$self->{out}->print("% подключаю гиперссылки синим цветом (рекомендуется последним)\n\\usepackage[colorlinks,urlcolor=blue]{hyperref}")};

    $self->{out}->print("\\begin{document}\n");
    foreach my $content (@content) {
	if($self->call($content)) { ; }
	elsif ($attr->{noescape}) { $self->{out}->print($content); }
	else { $self->{out}->print(&escape_latex($content)); }
    }
    $self->{out}->print("\\end{document}\n");
    $self->{out}->close() || die;
    system(PDFLATEX_PATH.' -interaction batchmode -halt-on-error -output-directory '.$attr->{dir}.' '.
	$attr->{dir}.$filename.'.tex >/dev/null 2>&1');
    if(!-s $attr->{dir}.$filename.'.pdf'){
	if(SHOW_TEX_AFTER_ERROR){
	    if(!&n($attr->{pdf}, 0)){
		$self->{out} = $self->{http};
		$self->{out}->no_cache(1);
		$self->{out}->send_http_header('text/plain');
	    }else{
		$self->{out} = *STDERR;
	    }
	    if(-s $attr->{dir}.$filename.'.tex'){
		my $tex = IO::File->new('<'.$attr->{dir}.$filename.'.tex') || die;
		while(read $tex, my $buf, 4096) { $self->{out}->print($buf); }
		$tex->close() || warn;
		$self->{out}->print("\n\n".('-' x 50)."\n\n");
	    }
	    if(-s $attr->{dir}.$filename.'.log'){
		my $log = IO::File->new('<'.$attr->{dir}.$filename.'.log') || die;
		while(read $log, my $buf, 4096) { $self->{out}->print($buf); }
		$log->close() || warn;
	    }
	}
	else { die 'Error create pdf', "\n"; }
    }
    elsif(&n($attr->{pdf}, 0)){ return $attr->{dir}.$filename.'.pdf'; }
    else {
	my $pdf = IO::File->new('<'.$attr->{dir}.$filename.'.pdf') || die;
	$self->{out} = $self->{http};
	if(&n($attr->{no_cache}, $self->{no_cache}, 1)) { $self->{out}->no_cache(1); }
	$self->{out}->headers_out_set('Content-Length' => (stat $attr->{dir}.$filename.'.pdf')[7]);
	$self->{out}->send_http_header('application/pdf');
	while(read $pdf, my $buf, 4096) { $self->{out}->print($buf); }
	$pdf->close() || warn;
    }
    &rmtree($attr->{dir}, 0, 0) if !&n($attr->{auto_del}, 1); # Очистить и удалить каталог $attr->{dir}
}

sub p {
	my $self = shift;
	my $attr = ref($_[0]) eq 'HASH' ? shift : {};
# 	my $content = shift;
	# Параметры тега выравнивания: { align=>'l', align=>'c', align=>'r', align=>'j'(по умолчанию) }
	my $start_p = '';
	my $end_p = "\\par\n";
	if (defined($attr->{align})) {
		if	($attr->{align} eq 'l') {$start_p = '\begin{flushleft}'; $end_p = "\\end{flushleft}\n"}
		elsif	($attr->{align} eq 'c') {$start_p = '\begin{center}'; $end_p = "\\end{center}\n"}
		elsif	($attr->{align} eq 'r') {$start_p = '\begin{flushright}'; $end_p = "\\end{flushright}\n"}}
		# elsif	($attr->{align} eq 'j') {$start_p = ''; $end_p = "\\par\n"}
	# Параметры тега "красной" строки: { indent=> кол-во мм}
	if($attr->{indent}) {$start_p .= '\hspace{'.$attr->{indent}."mm}\n";}
	# Параметры тега насыщенности: { bold=>0 или 1 }
	if (defined($attr->{bold})) {$start_p .= '{\bfseries '; $end_p = '}' . $end_p}
	# Параметры тега наклона: { italic=>0 или 1 }
	if (defined($attr->{italic})) {$start_p .= '{\itshape '; $end_p = '}' . $end_p}
	# Параметры тега подчеркивания: { u=>0 или 1 }
	if (defined($attr->{u})) {$start_p .= '\underline{'; $end_p = '}' . $end_p}
	# Параметры тега размера шрифта: { size=>число }
	if (defined($attr->{size})) {
		$start_p .= &fontsize($attr->{size});
		$end_p = '\normalfont{}'.$end_p;
	};
	# Параметры тега цвета шрифта: { color=>'red' или '#FF00FF' }
	if (defined($attr->{color})) {$start_p .= &color_name($attr->{color}); $end_p = '}'.$end_p;};

	$self->print($start_p);
# 	if(ref($content) eq 'CODE') {$content->()}
# 	elsif ($attr->{noescape}) {$self->print($content)}
# 	elsif ($content) {$self->printe($content)}
# 	else {$self->print('\strut{}')}
	if(!@_) { $self->{out}->print('\strut{}'); }
	elsif($attr->{noescape}) { $self->c(@_); }
	else { $self->ce(@_); }
	$self->print($end_p);
}

sub table {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    my @content = @_;
    ################################################УСТАНАВЛИВАЮ СВОЙСТВА#################################################
    # ширина таблицы в мм
    if (defined($attr->{width}))
	{$attr->{width} = $self->{doc_attr}->{textwidth} * $attr->{width} / 100}
	else
	{$attr->{width} = $self->{doc_attr}->{textwidth}};
    # является ли таблица вложенной?
    my $is_req = (exists($self->{table_attr})) ? 1 : 0;
    # Устанавливаем границы:
    #  	{ border=>0 } - без границ
    #  	{ border=>1 } - все границы (по умолчанию)
    #  	{ border=>2 } - только внутренние
    if (!defined($attr->{border})) {$attr->{border} = $is_req ? 2 : 1};
    # Устанавливаем отступ от границ таблицы: { cellpadding=>число (в миллиметрах) (по умолчанию устанавливается отступ документа) }
    if (!defined($attr->{cellpadding})) {$attr->{cellpadding} = $self->{doc_attr}->{cellpadding}};
    # Устанавливаем текущую строку для определения первой записи таблицы для вставки первой линии над таблицей
    $attr->{cur_rec} = 0;
    # Устанавливаем вертикальное выравнивание в таблице
    if (!defined($attr->{valign})) {$attr->{valign} = 't'};
    local $self->{table_attr} = $attr;
    ################################################СОЗДАЮ СТОЛБЦЫ#######################################################
    my $t_attr = '\begin{tabular}[t]{'; # все таблицы выравниваем по верхнему краю базовой линии строки
    my $c = 0; # порядковый номер столбца, чтобы не вставлять левую границу таблицы если я вложенная
    if (!defined($attr->{col})) {$attr->{col} = [{ width => 100 }]};
    my $c_all = scalar(@{$attr->{col}}) - 1; # всего столбцов для расчета ширины последнего столбца
    my $tw = $attr->{width}; # оставшаяся ширина таблицы для расчета ширины последнего столбца
    foreach my $col (@{$attr->{col}}) {
	# расчет ширины столбца
	$col->{width} = int($attr->{width} * $col->{width} / 100 ); # взятие процента
	if ($tw < $col->{width} or $c eq $c_all) {$col->{width} = $tw}; # ставлю ширину равную остатку для последнего столбца или 0 при переборе
	$tw -= $col->{width}; # вычитаю ширину столбца из ширины таблицы
	my $col_width = $col->{width} - $attr->{cellpadding} * 2; # устанавливаю ширину столбца с учетом отступов от границ
		$col_width = 0 if $col_width < 0;
	$self->{table_attr}->{col}->[$c]->{width} = $col_width;
	# запись столбца
	$t_attr .=
		# вставляю левую границу
		($attr->{border} == 1 ? '|' : '').
		($attr->{border} == 2 and $c > 0 ? '|' : '').
		# вставляю нестандартный отступ если он есть
		($attr->{cellpadding} == $self->{doc_attr}->{cellpadding} ? '' :
			($attr->{cellpadding} == 0) ? '@{}' :
			'@{\extracolsep{'.$attr->{cellpadding}.'mm}}').
		# вставляю столбец
		($self->{table_attr}->{valign} eq 't' ? 'p{'.$col_width.'mm}' :
			$self->{table_attr}->{valign} eq 'c' ? 'm{'.$col_width.'mm}' :
			$self->{table_attr}->{valign} eq 'b' ?  'b{'.$col_width.'mm}' : '').
		# вставляю нестандартный отступ если он есть
		($attr->{cellpadding} == $self->{doc_attr}->{cellpadding} ? '' :
			($attr->{cellpadding} == 0) ? '@{}' :
			'@{\extracolsep{'.$attr->{cellpadding}.'mm}}');
	$c++;
	};
    $self->{out}->print($t_attr, ($attr->{border} == 1 ? "|}\n" : "}\n"));
    ################################################ВЫВОД ТЕЛА ТАБЛИЦЫ####################################################
#     if(ref($content) eq 'CODE') { $content->(); } else { $self->{out}->print($content); }
    foreach my $content (@content) {
	if($self->call($content)) { ; }
	else { $self->{out}->print($content); }
    }
    ################################################ЗАКРЫВАЮ ТАБЛИЦУ######################################################
    $self->{out}->print(($attr->{border} == 1 ? "\\lasthline\n" : ''), '\end{tabular}', ($is_req ? '' : '\par'), "\n");
}

sub td_attr {
    my $self = shift;
    my $td_attr = shift;
    my $name = shift;
    return &n($td_attr->{$name}, $self->{row_attr}->{$name}, $self->{table_attr}->{$name});
}

sub tr {
    my $self = shift;
    local $self->{row_attr} = ref($_[0]) eq 'HASH' ? shift : {};
    # текущий столбец для определения ширины последнего столбца и определения выравнивания в столбце
    my $cur_col = 0;
    # вставляю верхнюю границу
    if ($self->{table_attr}->{border} == 1 and $self->{table_attr}->{cur_rec} == 0)
	{$self->{out}->print('\firsthline ')};
    if ($self->{table_attr}->{border} > 0 and $self->{table_attr}->{cur_rec} > 0)
	{$self->{out}->print('\hline ')};
    $self->{table_attr}->{cur_rec}++;
    # вставляю ячейки
    while(@_) {
	my $td_attr = ref($_[0]) eq 'HASH' ? shift : {};
	my $content = shift;
	# временно подменяю ширину страницы на ширину столбца
	local $self->{doc_attr}->{textwidth} = $self->{table_attr}->{col}->[$cur_col]->{width};
	# применяю параметры ячейки --------------------------------------------------------------------------------------
	my $s_s = '';
	my $s_e = '';
	# Параметры горизонтального выравнивания
	my $c_a = &n($td_attr->{halign},
	    $self->{row_attr}->{halign},
	    $self->{table_attr}->{col}->[$cur_col]->{halign},
	    $self->{table_attr}->{halign},
	    ''
	);
	if($self->{row_attr}->{th}){ $s_s = '\centering\arraybackslash '; }
	elsif ($c_a eq 'l') { $s_s = '\raggedright\arraybackslash '; }
	elsif ($c_a eq 'c') { $s_s = '\centering\arraybackslash '; }
	elsif ($c_a eq 'r') { $s_s = '\raggedleft\arraybackslash '; }
	# Параметры тега размера шрифта: { size=>число }
	if (defined $self->td_attr($td_attr, 'size'))
		{ $s_s .= &fontsize($self->td_attr($td_attr, 'size'));
		  $s_e  = '\normalfont' };
	# Параметры тега цвета шрифта: { color=>[палитра RGB] }
	if (defined $self->td_attr($td_attr, 'color')) {$s_s .= &color_name($self->td_attr($td_attr, 'color')); $s_e = '}'.$s_e;}
	# Параметры тега насыщенности: { bold=>0 или 1 }
	if ($self->{row_attr}->{th} || $self->td_attr($td_attr, 'bold'))
	    { $s_s .= '{\bfseries '; $s_e = '}'.$s_e }
	# Параметры тега подчеркивания: { u=>0 или 1 }
	if ($self->td_attr($td_attr, 'u')) {$s_s .= '\underline{'; $s_e = '}' . $s_e}
	# Параметры тега курсива: { italic=>0 или 1 }
	if ($self->td_attr($td_attr, 'italic')) { $s_s .= '{\itshape '; $s_e = '}'.$s_e }
	# Параметры тега "красной" строки: { indent=> кол-во мм}
	if(my $indent = $self->td_attr($td_attr, 'indent')) {$s_s .= '\hspace{'.$indent.'mm}';}
	#-----------------------------------------------------------------------------------------------------------------
	$self->print($s_s);
	if($self->call($content)) { ; }
	elsif($self->td_attr($self, $td_attr, 'noescape')) { $self->print($content); }
	else { $self->printe($content) };
	$self->print($s_e);
	if(@_) { $self->{out}->print(' & '); }
	$cur_col++;
    };
    # конец строки
    $self->{out}->print(" \\\\\n");
}

sub color_name {
    my $color = shift;
    if ($color eq 'black') {$color = '\textcolor{black}{'}
    elsif ($color eq 'red') {$color = '\textcolor{red}{'}
    elsif ($color eq 'blue') {$color = '\textcolor{blue}{'}
    elsif ($color eq 'purple') {$color = '\textcolor{magenta}{'}
    elsif ($color eq 'white') {$color = '\textcolor{white}{'}
    elsif ($color eq 'green') {$color = '\textcolor{green}{'}
    elsif ($color eq 'aqua') {$color = '\textcolor{cyan}{'}
    elsif ($color eq 'yellow') {$color = '\textcolor{yellow}{'}
    elsif ($color eq 'silver') {$color = '\textcolor[rgb]{'.&create_rgb('#C0C0C0').'}{'}
    elsif ($color eq 'gray') {$color = '\textcolor[rgb]{0.5,0.5,0.5}{'}
    elsif ($color eq 'maroon') {$color = '\textcolor[rgb]{'.&create_rgb('#800000').'}{'}
    elsif ($color eq 'fuchsia') {$color = '\textcolor[rgb]{'.&create_rgb('#FF00FF').'}{'}
    elsif ($color eq 'lime') {$color = '\textcolor[rgb]{'.&create_rgb('#00FF00').'}{'}
    elsif ($color eq 'olive') {$color = '\textcolor[rgb]{'.&create_rgb('#808000').'}{'}
    elsif ($color eq 'navy') {$color = '\textcolor[rgb]{'.&create_rgb('#000080').'}{'}
    elsif ($color eq 'teal') {$color = '\textcolor[rgb]{'.&create_rgb('#008080').'}{'}
    elsif ($color =~ m/^#?[\dABCDEF]{6}$/i) {$color = '\textcolor[rgb]{'.&create_rgb($color).'}{'}
    elsif (ref($color) eq 'ARRAY' || $color =~ m/^\d{1,3},\s?\d{1,3},\s?\d{1,3}$/) {$color = '\textcolor[rgb]{'.&create_rgb($color).'}{'}
    else { die; }
    return $color;
}

sub create_rgb {
    my $color = shift;
    my @rgb;
    if ($color =~ m/^#?[\dABCDEF]{6}$/i) {
	@rgb = $color =~ m/^#?(.{2})/g;
	map $_ = hex $_, @rgb;
    }
    elsif ($color =~ m/^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$/) {@rgb = ($1, $2, $3);}
    elsif (ref($color) eq 'ARRAY' && @$color == 3) {@rgb = @$color;}
    else { die 'Неправильно указан цвет: ', &d($color), "\n"; }
    foreach (@$color) {if($_ !~ /^\d+$/ || $_ > 255) {die "Неправильный компонент RGB: ", &d($_), "\n";} }
    map $_ = int(($_+1)*100/256)/100, @rgb;
    s/,/\./ for @rgb; # Почему-то иногда там не точка а запятая...
    return join(",", @rgb);
}

sub no {
    my $self = shift;
    $self->{out}->print('\No');
}

sub br {
    my $self = shift;
    $self->print('\par{}');
}

sub newpage {
    my $self = shift;
    $self->print('\newpage{}',"\n");
}

sub fmt_date {
    my $self = shift;
    my $date = shift;
    if($date !~ /^(\d{2,4})-(\d{2})-(\d{2})(?: \d\d:\d\d:\d\d)?$/) { warn $date; die; }
    my($y,$m,$d) = ($1,$2,$3);
    $self->{out}->print("<<$d>> $PageGen::Generic::MonthNames[$m] $y г.");
}

sub escape_latex {
    my $content = shift;
    if(!defined $content) {
	require Carp;
	&Carp::carp('undefined value in arg of escape_latex');
	return '';
    }
    $content =~ s/\\/\\\\/g; # удваиваю слэши
    $content =~ s/\{/\{{/g; # удваиваю скобку
    $content =~ s/}/\\}{}/g;
    $content =~ s/\{\{/\\{{}/g; # восстанавливаю скобку
    $content =~ s/\\\\/\\textbackslash{}/g; # восстанавливаю удвоенные слэши
    $content =~ s/#/\\#{}/g;
    $content =~ s/\$/\\\${}/g;
    $content =~ s/%/\\\%{}/g;
    $content =~ s/&/\\&{}/g;
    $content =~ s/_/\\_{}/g;
    $content =~ s/\^/\\textasciicircum{}/g;
    $content =~ s/~/\\textasciitilde{}/g;
    $content =~ s/"/\\textquotedbl{}/g;
# лапки
    $content =~ s/<</{<}{<}/g;
    $content =~ s/>>/{>}{>}/g;
    $content =~ s/"</{"}{<}/g;
    $content =~ s/">/{"}{>}/g;
# елочки
    $content =~ s/,,/{,}{,}/g;
    $content =~ s/``/{`}{`}/g;
    $content =~ s/"`/{"}{`}/g;
    $content =~ s/"'/{"}{'}/g;
    return $content;
}

sub img {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : ();

    my $dir = $self->{doc_attr}->{dir};
    if($dir !~ m/^\/tmp\//){ die; }
    my $suffix = $attr->{suffix} || &image_suffix($attr->{data});
    #content# if($suffix eq 'jpeg') { $suffix = 'jpg'; }
    my($fh, $filename) = File::Temp::tempfile(DIR => $dir, SUFFIX => '.'.$suffix);
    print $fh $attr->{data};
    close $fh;
    if($attr->{over}){
	$attr->{over}->{width} =~ s/,/./;
	$attr->{over}->{height} =~ s/,/./;
	$attr->{over}->{shiftX} =~ s/,/./;
	$attr->{over}->{shiftY} =~ s/,/./;
    }
    $self->{out}->print(
	$attr->{over} ?
	    ('\begin{picture}(',$attr->{over}->{width},',',$attr->{over}->{height},')(',
	    $attr->{over}->{shiftX},',',$attr->{over}->{shiftY},')') : (), # влево и вниз
	'\includegraphics',
	    ($attr->{latex_attr} ? ('[',$attr->{latex_attr},']') : ()),
	    '{',$filename,'}',
	$attr->{over} ? ('\end{picture}') : (),
    );
}

sub escape {my $self = shift; my $txt = shift; return &escape_latex($txt);}

sub href {
	my $self = shift;
	my $ref = shift;
	my $text = shift;
	if (!defined($self->{doc_attr}->{pdf_href})) {die}
	$self->print('\htmladdnormallink{', &escape_latex($text), '}{', $ref, '}');
}

=note
    $self->{out}->print("\n");
    $self->{out}->print("\n");
    $self->{out}->print("\n");
=cut

sub hr {
    my $self = shift;
    my $attr = shift || {};
    if(!defined($attr->{size})) { $attr->{size} = 1; }
    # ширина таблицы в мм
    if ($attr->{width}) {
	$attr->{width} = $self->{doc_attr}->{textwidth} * $attr->{width} / 100;
    } else { $attr->{width} = $self->{doc_attr}->{textwidth} }
    $self->{out}->print('\rule[0pt]{',$attr->{width},'mm}{',$attr->{size},"pt}\\par\n");
}

sub filling {
    my $self = shift;
    my $width = shift;
    my $text = shift || '';
    if($width =~ m/^\d+mm$/) { ; }
    elsif($width =~ m/^(\d+)%$/) { $width = int($self->{doc_attr}->{textwidth} * $1 / 100).'mm'; }
    else { die 'Нарушен формат ширины.'; }
    if($text) { $text = '\par{}\centering{}\footnotesize{'.&escape_latex($text).'}'; }
    $self->{out}->print("\\parbox[t]{$width}{\\hrulefill$text}\n");
}

sub fontsize {
    my $size = shift;
    if($size !~ m/^\d+$/) { die "Нарушен формат размера шрифта: $size"; }
    if   ($size < 1.5) { return ('\fontsize{'.5 .'}{'.6 .'}'); }
    elsif($size < 2.5) { return ('\fontsize{'.8 .'}{'.10 .'}'); }
    elsif($size < 3.5) { return ('\fontsize{'.10 .'}{'.12 .'}'); }
    elsif($size < 4.5) { return ('\fontsize{'.12 .'}{'.14 .'}'); }
    elsif($size < 5.5) { return ('\fontsize{'.14 .'}{'.17 .'}'); }
    elsif($size < 6.5) { return ('\fontsize{'.17 .'}{'.20 .'}'); }
    elsif($size < 7.5) { return ('\fontsize{'.20 .'}{'.25 .'}'); }
    else {
	warn "Превышен допустимый размер шрифта. Установлен максимальный размер.";
	return ('\fontsize{'.25 .'}{'.25 .'}');
    }
}

sub renewcommand {
    my $self = shift;
    while(@_) {
	my $name = shift;
	my $value = shift;
	if($name !~ /\A\w+\z/) { croak "bad command name '$name'"; }
	if(!defined $value) { $value = ''; }
	elsif(ref($value) eq 'ARRAY' && @$value == 2 && $value->[0] eq 'noescape') { $value = $value->[1]; }
	else { $value = &escape_latex($value); }
	$self->{out}->print('\\renewcommand{\\', $name, '}{', $value, "}\n");
    }
}

sub box {
    my $self = shift;
    my($width,$height,$box,$valign,$halign);
    my $width_print = '';
    if(!@_) { return; }
    elsif(ref($_[0]) eq 'HASH') {
	my $attr = shift;
	if(defined $attr->{width}){
	    die 'Нарушен формат ширины.' if $attr->{width} !~ m/^(\d+)(mm|%)$/;
	    ($width, my $edizm) = ($1,$2);
	    # взятие процента
	    if($edizm eq '%'){$width = int($width * $self->{doc_attr}->{textwidth} / 100 );}
	    $width_print = '{'.$width.'mm}';
	}
	if(defined $attr->{height}){
	    die 'Нарушен формат высоты.' if $attr->{height} !~ m/^\d+mm$/;
	    $height = $attr->{height};
	}
	if(defined $attr->{border}){
	    die 'Нарушен формат рамки.' if $attr->{border} !~ m/^\d+$/;
	    $box = '\setlength{\fboxrule}{'.$attr->{border}.'pt}';
# 	    if($height){
# 		$box .= '\newdimen\tmplengthheightfromboxinline\setlength{\tmplengthheightfromboxinline}{'.$height.
# 		    '}\addtolength{\tmplengthheightfromboxinline}{-2\fboxsep}';
# 		$height = '\tmplengthheightfromboxinline';
# 	    }
# 	    if($width){
# 		$box .= '\newdimen\tmplengthwidthfromboxinline\setlength{\tmplengthwidthfromboxinline}{'.$width.
# 		    'mm}\addtolength{\tmplengthwidthfromboxinline}{-2\fboxsep}';
# 		$width_print = '{\tmplengthwidthfromboxinline}';
# 	    }
	    $box = '{'.$box.'\fbox{';
# \fbox\parbox{w,h}
	}else{
	    $box = '{\mbox{';
	}
	if(defined $attr->{valign}){
	    if($attr->{valign} eq 't'){ $valign = '[t]'; }
	    elsif($attr->{valign} eq 'c'){ $valign = '[c]'; }
	    elsif($attr->{valign} eq 'b'){ $valign = '[b]'; }
	}else{
	    $valign = '[t]';
	}
	if(defined $attr->{halign}){
	    if($attr->{halign} eq 'l'){ $halign = '\raggedright\arraybackslash '; }
	    elsif($attr->{halign} eq 'c'){ $halign = '\centering\arraybackslash '; }
	    elsif($attr->{halign} eq 'r'){ $halign = '\raggedleft\arraybackslash '; }
	}
    }
    local $self->{doc_attr}->{textwidth} = $width || $self->{doc_attr}->{textwidth};
    $height = $height ? '['.$height.']': '';
    $self->{out}->print($box,($width ? ('\parbox',$valign,$height,$width_print) : '\mbox'),'{\strut ');
    foreach my $content (@_) {
	if(!$self->call($content)){ $self->{out}->print(&escape_latex($content)); }
    }
    $self->{out}->print('}}}');
}

# sub b {
#     my $self = shift;
#     my $attr = ref($_[0]) eq 'HASH' ? shift : {};
#     $self->{out}->print('{\bfseries ');
#     if($attr->{noescape}) { $self->c(@_); } else { $self->ce(@_); }
#     $self->{out}->print('}');
# }

sub formatted_text {
    my $format = shift;
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    $self->{out}->print($format);
    if($attr->{noescape}) { $self->c(@_); } else { $self->ce(@_); }
    $self->{out}->print('}');
}

BEGIN {
    foreach(
	['b', '{\bfseries '],
	['i', '{\itshape '],
	['u', '\underline{'],
    ) {
	eval "sub $_->[0] { &formatted_text('$_->[1]', \@_); }";
	#if($EVAL_ERROR) { die; }
    }
}

sub clear_files {
    my $self = shift;
    return if !$self->{tmp_files} or ref($self->{tmp_files}) ne 'ARRAY';
    for(my $i=0;$i<@{$self->{tmp_files}};$i++){
	&rmtree($self->{tmp_files}->[$i], 0, 0); # Очистить и удалить каталог
    }
}

sub DESTROY {
    my $self = shift;
    $self->clear_files();
}
