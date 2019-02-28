#!/usr/bin/perl

use warnings;
use strict;
use NetParse;
use NetConvert;
use NetAnalyze;
use InstrAnalyze;

#some layer not clear yet;
#my $file = './v2verification/net/13_ssd_origin.prototxt';

#my $file = './v2verification/net/09_resnet50.prototxt';
#my $file = './v2verification/net/10_resnet152.prototxt';
#my $file = './v2verification/net/19_yolo_v2_1.prototxt';
#my $file = './v2verification/net/20_vgg16.prototxt';
#my $file = './v2verification/net/21_googlenet_v1.prototxt';
#my $file = './v2verification/net/22_googlenet_v2.prototxt';
#my $file = './v2verification/net/23_googlenet_v3.prototxt';
#my $file = './v2verification/net/37_yolo_v2_2.prototxt';
#my $file = './v2verification/net/40_mobilenet.prototxt';
my $file = './mobilenet_v2.prototxt';
#my $file = './v2verification/net/70_alexnet.prototxt';
#my $file = './lh_rcnn/xcept.prototxt';
#my $file = './lh_rcnn/xception_lh.prototxt';

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

#foreach(@name){
#    if(defined($net_aggr{$_})){
#        print $_, "    ";
#        my %lr_info = %{$net_aggr{$_}};
#        print $lr_info{"type"}, "    ";
#        print $lr_info{"channel_in"}, "    ";
#        print $lr_info{"height_in"}, "    ";
#        print $lr_info{"width_in"}, "    ";
#        print $lr_info{"channel_out"}, "    ";
#        print $lr_info{"height_out"}, "    ";
#        print $lr_info{"width_out"}, "    ";
#        print "\n";
#    }
#}

my $e = &NetAnalyze::net_analyze(\%net_aggr);
my %net_rlt = %{$e};
&NetAnalyze::net_dump(\%net_rlt, \%net, \@name);

#my $indir = "./resnet";
#my $indir = "./inception_v1";
#my $x = &InstrAnalyze::net_instr_analyze($indir);
#my %layer_mem = %{$x};
#&InstrAnalyze::net_instr_dump(\%layer_mem);
