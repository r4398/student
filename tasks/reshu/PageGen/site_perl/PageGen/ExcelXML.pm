package PageGen::ExcelXML;

use strict;
use English;
use DbEdit::Request;
use base qw(PageGen::Generic);
use PageGen::XML;
use Reshu::Utils;
use Reshu::UtilsDBI '&sqlftime';

1;

BEGIN {
    *escape_param = \&PageGen::XML::escape_param;
    *escape_data = \&PageGen::XML::escape_data;
    *print_attr = \&PageGen::XML::print_attr;
    *check_tag_name = \&PageGen::XML::verify_el;
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
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
	xmlns:o="urn:schemas-microsoft-com:office:office"
	xmlns:x="urn:schemas-microsoft-com:office:excel"
	xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
	xmlns:html="http://www.w3.org/TR/REC-html40">
');

    if(!exists($attr->{styles}) || $attr->{styles}) {
	my $r = ref $attr->{styles};
	my $a = '<Styles>
<Style ss:ID="th"><Alignment ss:Horizontal="Center"/><Font ss:Bold="1"/></Style>
<Style ss:ID="sd"><NumberFormat ss:Format="Short Date"/></Style>';
	my $b = '
</Styles>
';
	if(!$r) {
	    $self->{out}->print($a, ($attr->{styles}||''), $b);
	}
	elsif($r eq 'ARRAY') {
	    if($attr->{styles}[0] eq 'Styles') { $self->ce($attr->{styles}); }
	    else {
		$self->{out}->print($a, "\n");
		foreach my $content (@{$attr->{styles}}) {
		    if(!$self->call($content)) { die "Ошибка формата: ", &d($content); }
		}
		$self->{out}->print($b);
	    }
	}
	elsif($r eq 'HASH') {
	    $self->{out}->print('<Styles>
');
	    if(!exists $attr->{styles}{th}) { $attr->{styles}{th} = ['ce', ['Alignment', {Horizontal => 'Center'}], ['Font', {Bold => 1}]]; }
	    if(!exists $attr->{styles}{sd}) { $attr->{styles}{sd} = ['NumberFormat', {Format => 'Short Date'}]; }
	    while(my($k,$v) = each %{$attr->{styles}}) { if($v) {
		if(ref $v) {
		    if(ref($v) eq 'ARRAY' && @$v && ref($v->[0]) eq 'ARRAY') {
			$self->Style({ID => $k}, ['ce', @$v]);
		    }
		    else { $self->Style({ID => $k}, $v); }
		}
		else { $self->Style({ID => $k}, ['c', $v]); }
	    } }
	    $self->{out}->print($b);
	}
	else { die; }
    }

    foreach my $content (@_) { if(!$self->call($content)) { die "Ошибка формата: ", &d($content); } }
    $self->{out}->print("</Workbook>\n");
}

sub table {
    my $self = shift;
    local $self->{table_attr} = my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    local $self->{table_data} = { rows => 0, cols => 0 };
    $self->{out}->print('<Worksheet');
    $self->ss_attr(Name => $attr->{name});
    $self->{out}->print("><Table>\n");

    if($attr->{column}){
        my $col_num;
        foreach my $col ( @{$attr->{column}} ){
            $col_num++;
            if($col) {
		if($col =~ /\Ah(\d+)\z/ ) {
		    $self->{out}->print(qq{<Column ss:Index="$col_num" ss:Hidden="1" ss:Span="$1"/>});
		    $col_num += $1 - 1;
		}
		else {
		    $self->{out}->print(qq{<Column ss:Index="$col_num" ss:AutoFitWidth="0" ss:Width="$col" />});
		}
            }
        }
    }

    foreach my $content (@_) { if(!$self->call($content)) { die "Ошибка формата: ", &d($content); } }
    my(@opts);
    if($attr->{split_hor}) { push @opts, ['c', "<FrozenNoSplit/>\n"], ['tag', 'SplitHorizontal', $attr->{split_hor}], "\n", ['tag', 'TopRowBottomPane', $attr->{split_hor}], "\n", ['tag', 'ActivePane', 2], "\n"; }
    $self->c("</Table>",
	@opts ? ("\n", ['tag', 'WorksheetOptions', { raw_attr => 'xmlns="urn:schemas-microsoft-com:office:excel"' }, "\n", @opts], "\n") : (),
        sub{
            if($attr->{selected}) { $self->c('<Selected/>'); }
            my $xind = 1;
            if($attr->{auto_filter} && @{$attr->{auto_filter}} ){
#         $self->c('
#         <AutoFilter x:Range="R1C1:R'.$self->{table_data}->{rows}.'C'.$self->{table_data}->{cols}.'"
#        xmlns="urn:schemas-microsoft-com:office:excel">');
        $self->c('
        <AutoFilter x:Range="R1C1:R65000C'.$self->{table_data}->{cols}.'"
       xmlns="urn:schemas-microsoft-com:office:excel">');
            foreach( @{$attr->{auto_filter}} ){
                if( $_ ) {
                    $self->c('
       <AutoFilterColumn x:Index="'.$xind.'" x:Type="Custom">
        <AutoFilterCondition x:Operator="Equals" x:Value="'.$_.'"/>
       </AutoFilterColumn>');
                }
                $xind ++;
            }
            $self->c('</AutoFilter>');
            }
            if($attr->{print}) {
            $self->c('<WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">');
                if($attr->{print}->{album}) {
                    $self->c('<PageSetup><Layout x:Orientation="Landscape"/></PageSetup>');
                }
$self->c('<Print>
<ValidPrinterInfo/>');
            foreach ( keys %{$attr->{print}} ) { 
                if($_ eq 'album'){next}
                $self->c('<'.$_.'>'.$attr->{print}->{$_}.'</'.$_.'>'); 
            }
$self->c('</Print>
</WorksheetOptions>');
            }
            if( $attr->{page_break} ) {
$self->c('<ShowPageBreakZoom/>
<PageBreaks xmlns="urn:schemas-microsoft-com:office:excel">');
                if( $attr->{page_break}->{col} ) {
                    $self->c('<ColBreaks>');
                    foreach ( @{$attr->{page_break}->{col}} ) {
$self->c("<ColBreak>
 <Column>$_->[0]</Column>
 <RowEnd>$_->[1]</RowEnd>
</ColBreak>");
                    }
                    $self->c('</ColBreaks>');
                }
                if( $attr->{page_break}->{row} ) {
                    $self->c('<RowBreaks>');
                    foreach ( @{$attr->{page_break}->{row}} ) {
$self->c("<RowBreak>
 <Row>$_->[0]</Row>
 <ColEnd>$_->[1]</ColEnd>
</RowBreak>");
                    }
                    $self->c('</RowBreaks>');
                }
                $self->c('</PageBreaks>');
            }
        } ,
	"</Worksheet>\n");
}

sub row {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    $self->{table_data}->{rows}++;
    $self->{table_data}->{cur_cols} = 0;
    local $self->{table_data}->{empty_cols};
    $self->{out}->print("<Row ");
    while(my($k,$v) = each %$attr) { $self->ss_attr($k, $v); }
    $self->{out}->print(">\n");
    foreach my $content (@_) {
	if(!$content) { $self->{table_data}->{cur_cols}++; $self->{table_data}->{empty_cols}++; }
	elsif(!$self->call($content)) { die "Ошибка формата: ", &d($content); }
    }
    $self->{out}->print("</Row>\n");
    if($self->{table_data}->{cols} < $self->{table_data}->{cur_cols}) {
	$self->{table_data}->{cols} = $self->{table_data}->{cur_cols};
    }
}

sub cell_data {
    my $self = shift;
    my $type = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    if(my $attr_style = $attr->{style}) {
	$attr = {%$attr};
	delete $attr->{style};
	$attr->{StyleID} = $attr_style;
    }
    foreach my $content (@_) {
	$self->{table_data}->{cur_cols}++;
	if(!defined $content) {
	    $self->{table_data}->{empty_cols}++;
	    next;
	}
	$self->{out}->print("<Cell");
	if($self->{table_data}->{empty_cols}) {
	    if(!$attr->{Index}) { $self->ss_attr(Index => $self->{table_data}->{cur_cols}); }
	    $self->{table_data}->{empty_cols} = 0;
	}
	if(!$attr->{StyleID}) { $self->ss_attr(StyleID => $self->{doc_attr}{style}); }
	while(my($k,$v) = each %$attr) { $self->ss_attr($k, $v); }
	$self->{out}->print("><Data ss:Type=\"$type\">");
	if(!$self->call($content)) {
	    if($attr->{noescape}) { $self->{out}->print($content); }
	    else { $self->{out}->print(&escape_data($content)); }
	}
	$self->{out}->print("</Data></Cell>\n");
    }
}

sub num { my $self = shift; foreach(@_){ s/,/./ if defined($_) } $self->cell_data('Number', @_); }
sub str { my $self = shift; $self->cell_data('String', @_); }

sub date {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
    if($attr->{doc_style}) { $attr = { %$attr }; delete $attr->{doc_style}; }
    elsif(!defined($attr->{style}) && !defined($attr->{StyleID})) { $attr->{StyleID} = 'sd'; }
    $self->cell_data('DateTime', $attr, map defined($_) ? &sqlftime('%Y-%m-%dT%H:%M:%S.000', $_) : $_, @_);
}

sub formula {
    my $self = shift;
    my $attr = ref($_[0]) eq 'HASH' ? shift : {};
#     my $type = shift;
    if(my $attr_style = $attr->{style}) {
	$attr = {%$attr};
	delete $attr->{style};
	$attr->{StyleID} = $attr_style;
    }
    foreach my $content (@_) {
	$self->{table_data}->{cur_cols}++;
	if(!defined $content) {
	    $self->{table_data}->{empty_cols}++;
	    next;
	}
	$self->{out}->print("<Cell");
	if($self->{table_data}->{empty_cols}) {
	    if(!$attr->{Index}) { $self->ss_attr(Index => $self->{table_data}->{cur_cols}); }
	    $self->{table_data}->{empty_cols} = 0; 
	}
	if(!$attr->{StyleID}) { $self->ss_attr(StyleID => $self->{doc_attr}{style}); }
	while(my($k,$v) = each %$attr) { $self->ss_attr($k, $v); }
	$self->ss_attr(Formula => $content);
	$self->{out}->print(" />");
    }
}

sub ss_attr { my $self = shift; my $name = shift; $self->print_attr('ss:'.$name, @_); }
sub attr { my $self = shift; my $name = shift; $self->print_attr($name, @_); }
sub style { my $self = shift; $self->{doc_attr}{style} = shift; }

sub tag {
    my $self = shift;
    my $tag = shift;
    &check_tag_name($tag);
    my $attr = @_ && ref($_[0]) eq 'HASH' ? shift : {};
    $self->{out}->print("<$tag", $attr->{raw_attr} ? (' ', $attr->{raw_attr}) : ());
    my $xml_attr;
    if(exists($attr->{raw_attr}) || exists($attr->{noescape}) || exists($attr->{no_ss_attr})) {
	$xml_attr = @_ && ref($_[0]) eq 'HASH' ? shift : {};
    }
    else { $xml_attr = $attr; }
    if(!$attr->{no_ss_attr}) { while(my($k,$v) = each %$xml_attr) { $self->ss_attr($k, $v); } }
    else { while(my($k,$v) = each %$xml_attr) { $self->attr($k, $v); } }
    if(@_) {
	$self->{out}->print(">");
	if($attr->{noescape}) { $self->c(@_); } else { $self->ce(@_); }
	$self->{out}->print("</$tag>");
    }
    else {
	$self->{out}->print(" />");
    }
}

BEGIN {
    foreach my $tag (qw(
	Styles Style Borders Border Font Interior NumberFormat Protection Alignment Column Data
    )) { eval "sub $tag { my \$self = shift; \$self->tag('$tag', \@_); }"; }
}

sub Cell {
    my $self = shift;
    if($self->{table_data}->{empty_cols}) { die; }
    $self->{table_data}->{cur_cols}++;
    $self->tag('Cell', @_);
}
