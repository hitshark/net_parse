#!/usr/bin/perl

use warnings;
use strict;
use NetParse;
use NetConvert;
use NetAnalyze;

#some layer not clear yet;
my $file = './net_desc/resnet50.prototxt';

my ($a, $b) = &NetParse::net_parse($file);
my %net = %{$a};
my @name = @{$b};

#foreach(@name){
#    print $_, "    ";
#    my %lr_info = %{$net{$_}};
#    my $type = $lr_info{"type"};
#    print $type, "\n";
#}

my $c = &NetConvert::net_extension(\%net, \@name);
my %net_ext = %{$c};
my $d = &NetConvert::net_aggregation(\%net_ext, \@name);
my %net_aggr = %{$d};

my $e = &NetAnalyze::net_analyze(\%net_aggr);
my %net_rlt = %{$e};
&NetAnalyze::net_dump(\%net_rlt, \@name);
