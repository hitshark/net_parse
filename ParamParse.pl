#!/usr/bin/perl

# function description
# parse the layer-parameter graph file to get the layer information
# of a network

#package ParamParse 1.0;

use warnings;
use strict;
use POSIX;
use POSIX;

# global variable for the hardware parameters
my %params;
open(KEY, '<', "dpu.cfg") or die "could not open dpu.cfg for $!\n";
while(<KEY>){
    if($_ =~ /(^[\w_]+)\s+(\d+)\s*$/){
        $params{$1} = $2;
    }
}
my $elew_paral =  $params{"elew_pp_h"} * $params{"elew_pp_w"} *
                $params{"elew_cp_out"} * $params{"elew_cp_in"} * $params{"elew_kp_h"} *
                $params{"elew_kp_w"} * $params{"elew_batch"};
my $pool_paral =  $params{"pool_pp_h"} * $params{"pool_pp_w"} *
                $params{"pool_cp_out"} * $params{"pool_cp_in"} * $params{"pool_kp_h"} *
                $params{"pool_kp_w"} * $params{"pool_batch"};
my $dw_paral = $params{"dw_pp_h"} * $params{"dw_pp_w"} *
                 $params{"dw_cp_out"} * $params{"dw_cp_in"} * $params{"dw_kp_h"} *
                 $params{"dw_kp_w"} * $params{"dw_batch"};
my $conv_paral = $params{"conv_pp_h"} * $params{"conv_pp_w"} *
                 $params{"conv_cp_out"} * $params{"conv_cp_in"} * $params{"conv_kp_h"} *
                 $params{"conv_kp_w"} * $params{"conv_batch"};


sub ParseParam {
    # open the layer parameter file
    open(FIN, '<', $_[0]) or die "could not open $_ for $!\n";

    # get super_layer, layer, and blob information
    my @super;
    my %layer, my %blob;
    while(my $start_line = <FIN>) {
        my %super_ele;
        my @tensor;
        if($start_line =~ /^GLOBALVAR\s+(.*)/) {
            my %param = split /[\s\s]/, $1;
            $super_ele{"name"} = $param{"str_name"};

            my $line;
            while(defined($line = <FIN>) && ($line !~ /^#/)) {
                if ($line =~ /^BLOB\s+(.*)/) {
                    my %param = split /[\s\s]/, $1;
                    $blob{$param{"str_name"}} = \%param;
                }
                elsif ($line =~ /^(\w+)\s+(.*)/) {
                    my %param = split /[\s\s]/, $2;
                    $param{"type"} = $1;
                    $layer{$param{"str_name"}} = \%param;
                    push(@tensor, $param{"str_name"});
                }
            }
            $super_ele{"ops"} = \@tensor;
            push(@super, \%super_ele);
        }
    }

    # get tensor information of each layer
    my %layer_info;
    foreach (keys %layer) {
        my %lyr = %{$layer{$_}};
        my $type = $lyr{"type"};

        my %layer_ele, my %blob_in;
        $layer_ele{"type"} = $type;

        if($type eq "LCONV" or $type eq "LDEPTHWISECONV" or $type eq "LPOOL") {
            $layer_ele{"kernel_h"} = $lyr{"kernel_h"};
            $layer_ele{"kernel_w"} = $lyr{"kernel_w"};
            $layer_ele{"stride_h"} = $lyr{"stride_h"};
            $layer_ele{"stride_w"} = $lyr{"stride_w"};
        }

        # just consider two inputs
        if ($type eq "LELEW" or $type eq "LCONCAT") {
            %blob_in = %{$blob{$lyr{"str_in0"}}};
        }
        else {
            %blob_in = %{$blob{$lyr{"str_in"}}};
        }

        $layer_ele{"height_in"} = $blob_in{"height"};
        $layer_ele{"width_in"} = $blob_in{"width"};
        $layer_ele{"channel_in"} = $blob_in{"channel"};

        my %blob_out = %{$blob{$lyr{"str_out"}}};
        $layer_ele{"height_out"} = $blob_out{"height"};
        $layer_ele{"width_out"} = $blob_out{"width"};
        $layer_ele{"channel_out"} = $blob_out{"channel"};

        $layer_info{$lyr{"str_name"}} = \%layer_ele;
    }

    return (\@super, \%layer_info);
}


sub CalcParam {
    my %layers = %{$_[0]};
    my %lyr_rlt;

    foreach (keys %layers) {
        my $lyr_name = $_;
        my %lyr = %{$layers{$lyr_name}};
        my $type = $lyr{"type"};

        if($type eq "LCONV") {
            my $tmp = $lyr{"channel_out"} * $lyr{"height_out"} * $lyr{"width_out"} * $lyr{"kernel_h"} * $lyr{"kernel_w"} * $lyr{"channel_in"};
            $lyr{"ops"}      = (2 * $tmp) / (1000*1000);
            my $align_tmp = POSIX::ceil($lyr{"channel_out"} / $params{"conv_cp_out"}) *
                            POSIX::ceil($lyr{"height_out"} / $params{"conv_pp_h"}) *
                            $lyr{"width_out"} *
                            $lyr{"kernel_h"} * $lyr{"kernel_w"} *
                            POSIX::ceil($lyr{"channel_in"} / $params{"conv_cp_in"});

            $lyr{"cycles"}   = $align_tmp;
            $lyr{"weight"}   = $lyr{"channel_out"} * $lyr{"kernel_h"} * $lyr{"kernel_w"} * $lyr{"channel_in"} / (1000*1000);
        }
        elsif($type eq "LDEPTHWISECONV") {
            my $tmp = $lyr{"channel_out"} * $lyr{"height_out"} * $lyr{"width_out"} * $lyr{"kernel_h"} * $lyr{"kernel_w"};
            $lyr{"ops"}      = (2 * $tmp) / (1000*1000);
            my $align_tmp = POSIX::ceil($lyr{"channel_out"} / $params{"dw_cp_in"}) *
                            POSIX::ceil($lyr{"height_out"} / $params{"dw_pp_h"}) *
                            $lyr{"width_in"} *
                            $lyr{"kernel_h"};

            $lyr{"cycles"}   = $align_tmp;
            $lyr{"weight"}   = $lyr{"channel_out"} * $lyr{"kernel_h"} * $lyr{"kernel_w"} / (1000*1000);
        }
        elsif($type eq "LPOOL") {
            my $tmp = $lyr{"channel_out"} * $lyr{"height_out"} * $lyr{"width_out"} * $lyr{"kernel_h"} * $lyr{"kernel_w"};
            $lyr{"ops"}      = $tmp / (1000*1000);
            my $align_tmp = POSIX::ceil($lyr{"channel_out"} / $params{"pool_cp_in"}) *
                            POSIX::ceil($lyr{"height_out"} / $params{"pool_pp_h"}) *
                            $lyr{"width_out"} *
                            $lyr{"kernel_h"} * $lyr{"kernel_w"};
            $lyr{"cycles"}   = $align_tmp;
            $lyr{"weight"}   = 0;
        }
        elsif($type eq "LELEW") {
            my $tmp = $lyr{"channel_out"} * $lyr{"height_out"} * $lyr{"width_out"};
            $lyr{"ops"}      = $tmp / (1000*1000);
            my $align_tmp = POSIX::ceil($lyr{"channel_out"} / $params{"elew_cp_in"}) *
                            POSIX::ceil($lyr{"height_out"} / $params{"elew_pp_h"}) *
                            $lyr{"width_out"};
            $lyr{"cycles"}   = $align_tmp;
            $lyr{"weight"}   = 0;
        }
        else {
            $lyr{"ops"} = 0;
            $lyr{"cycles"}   = 0;
            $lyr{"weight"}   = 0;
        }

        $lyr_rlt{$lyr_name} = \%lyr;
    }


    # sum information of each type
    my %sum_all;
    $sum_all{"name"} = "sum_all";
    $sum_all{"type"} = "none";
    $sum_all{"ops"} = 0;
    $sum_all{"weight"} = 0;
    $sum_all{"cycles"} = 0;
    foreach(keys(%lyr_rlt)){
        my %lr_info = %{$lyr_rlt{$_}};
        $sum_all{"ops"}      += $lr_info{"ops"};
        $sum_all{"weight"}   += $lr_info{"weight"};
        $sum_all{"cycles"}   += $lr_info{"cycles"};
    }
    $lyr_rlt{"sum_all"} = \%sum_all;

    my %sum_conv;
    $sum_conv{"name"} = "sum_conv";
    $sum_conv{"type"} = "none";
    $sum_conv{"ops"} = 0;
    $sum_conv{"weight"} = 0;
    $sum_conv{"cycles"} = 0;
    foreach(keys(%lyr_rlt)){
        my %lr_info = %{$lyr_rlt{$_}};
        if($lr_info{"type"} eq "LCONV") {
            $sum_conv{"ops"}      += $lr_info{"ops"};
            $sum_conv{"weight"}   += $lr_info{"weight"};
            $sum_conv{"cycles"}   += $lr_info{"cycles"};
        }
    }
    $lyr_rlt{"sum_conv"} = \%sum_conv;

    my %sum_dwconv;
    $sum_dwconv{"name"} = "sum_dwconv";
    $sum_dwconv{"type"} = "none";
    $sum_dwconv{"ops"} = 0;
    $sum_dwconv{"weight"} = 0;
    $sum_dwconv{"cycles"} = 0;
    foreach(keys(%lyr_rlt)){
        my %lr_info = %{$lyr_rlt{$_}};
        if($lr_info{"type"} eq "LDEPTHWISECONV") {
            $sum_dwconv{"ops"}      += $lr_info{"ops"};
            $sum_dwconv{"weight"}   += $lr_info{"weight"};
            $sum_dwconv{"cycles"}   += $lr_info{"cycles"};
        }
    }
    $lyr_rlt{"sum_dwconv"} = \%sum_dwconv;

    my %sum_pool;
    $sum_pool{"name"} = "sum_pool";
    $sum_pool{"type"} = "none";
    $sum_pool{"ops"} = 0;
    $sum_pool{"weight"} = 0;
    $sum_pool{"cycles"} = 0;
    foreach(keys(%lyr_rlt)){
        my %lr_info = %{$lyr_rlt{$_}};
        if($lr_info{"type"} eq "LPOOL") {
            $sum_pool{"ops"}      += $lr_info{"ops"};
            $sum_pool{"weight"}   += $lr_info{"weight"};
            $sum_pool{"cycles"}   += $lr_info{"cycles"};
        }
    }
    $lyr_rlt{"sum_pool"} = \%sum_pool;

    my %sum_elew;
    $sum_elew{"name"} = "sum_elew";
    $sum_elew{"type"} = "none";
    $sum_elew{"ops"} = 0;
    $sum_elew{"weight"} = 0;
    $sum_elew{"cycles"} = 0;
    foreach(keys(%lyr_rlt)){
        my %lr_info = %{$lyr_rlt{$_}};
        if($lr_info{"type"} eq "LELEW") {
            $sum_elew{"ops"}      += $lr_info{"ops"};
            $sum_elew{"weight"}   += $lr_info{"weight"};
            $sum_elew{"cycles"}   += $lr_info{"cycles"};
        }
    }
    $lyr_rlt{"sum_elew"} = \%sum_elew;

    return (\%lyr_rlt);
}


sub DumpParam{
    my @supers = @{$_[0]};
    my %layers = %{$_[1]};

    printf "%-90s", "name";
    printf "%-18s", "type";
    printf "%-18s", "input";
    printf "%-18s", "output";
    printf "%-10s", "kernel";
    printf "%-10s", "stride";
    printf "%-10s", "weight/M";
    printf "%-10s", "ops/M";
    printf "%-10s", "cycles";
    printf "%-10s", "conv/dw";
    printf "\n";

    foreach(@supers){
        my %super_lyr = %{$_};
        printf "%-90s\n", $super_lyr{"name"};

        my @ops = @{$super_lyr{"ops"}};
        my $conv_cycle = 0;
        foreach (@ops) {
            my %lyr = %{$layers{$_}};
            my $type = $lyr{"type"};

            printf "%-90s", $_;
            printf "%-18s", $type;
            printf "%-18s", $lyr{"height_in"}."x".$lyr{"width_in"}."x".$lyr{"channel_in"};
            printf "%-18s", $lyr{"height_out"}."x".$lyr{"width_out"}."x".$lyr{"channel_out"};

            if($type eq "LCONV" or $type eq "LDEPTHWISECONV" or $type eq "LPOOL") {
                printf "%-10s", $lyr{"kernel_h"}."x".$lyr{"kernel_w"};
                printf "%-10s", $lyr{"stride_h"}."x".$lyr{"stride_w"};
            }
            else {
                my $empty = "";
                printf "%-10s", $empty;
                printf "%-10s", $empty;
            }

            printf "%-10.03f", $lyr{"weight"};
            printf "%-10.03f", $lyr{"ops"};
            printf "%-10.f", $lyr{"cycles"};

            if($type eq "LCONV") { $conv_cycle = $lyr{"cycles"}; }
            elsif(($type eq "LDEPTHWISECONV") and ($conv_cycle != 0)) {
                my $rate = $conv_cycle / $lyr{"cycles"};
                printf "%-10.03f", $rate;
            }
            printf "\n";
        }
        $conv_cycle = 0;
    }

    my @summary = ("sum_all", "sum_conv", "sum_dwconv", "sum_pool", "sum_elew");
    foreach (@summary) {
        my %lyr = %{$layers{$_}};
        printf "%-90s", $_;
        printf "%-18s", $lyr{"type"};
        printf "%-18s", "";
        printf "%-18s", "";
        printf "%-10s", "";
        printf "%-10s", "";
        printf "%-10.03f", $lyr{"weight"};
        printf "%-10.03f", $lyr{"ops"};
        printf "%-10.f", $lyr{"cycles"};
        printf "\n";
    }
}


my $file = "./retina/retina_layer_param.txt";
my ($a, $b) = &ParseParam($file);
my @spr = @{$a};
my %net = %{$b};
my $c = &CalcParam(\%net);
my %net_rlt = %{$c};
&DumpParam(\@spr, \%net_rlt);

#1;
