#!/usr/bin/perl

# function description
# analyze the network and get the following statistics:
#   operations per-layer;
#   input/output size for each layer;
#   weight size for each layer;
#   summary of the net;
# interface:
#   %net_rlt <= net_analyze(%net_aggr);
#   net_dump(%net_rlt, @layer_name);

package NetAnalyze 1.0;

use warnings;
use strict;

sub net_analyze{
    my %net = %{$_[0]};             # get the net parameter
    my %net_rlt;                    # store the analyzed net info.
    foreach(keys(%net)){
        my $lr_name = $_;
        my %lr_info = %{$net{$lr_name}};
        my %lr_rlt;
        my $type = $lr_info{"type"};

        $lr_rlt{"name"}     = $lr_name;
        $lr_rlt{"type"}     = $type;
        $lr_rlt{"data_in"}  = $lr_info{"channel_in"} * $lr_info{"height_in"} * $lr_info{"width_in"} / (1000*1000);
        $lr_rlt{"data_out"} = $lr_info{"channel_out"} * $lr_info{"height_out"} * $lr_info{"width_out"} / (1000*1000);
        if($type eq "Convolution"){
            $lr_rlt{"ops"}      = (2 * $lr_info{"channel_out"} * $lr_info{"height_out"} * $lr_info{"width_out"} * $lr_info{"kernel_h"} * $lr_info{"kernel_w"} * $lr_info{"channel_in"}) / (1000*1000);
            $lr_rlt{"weight"}   = $lr_info{"channel_out"} * $lr_info{"kernel_h"} * $lr_info{"kernel_w"} * $lr_info{"channel_in"} / (1000*1000);
        }
        elsif($type eq "DepthWiseConv"){
            $lr_rlt{"ops"}      = (2 * $lr_info{"channel_out"} * $lr_info{"height_out"} * $lr_info{"width_out"} * $lr_info{"kernel_h"} * $lr_info{"kernel_w"}) / (1000*1000);
            $lr_rlt{"weight"}   = $lr_info{"channel_out"} * $lr_info{"kernel_h"} * $lr_info{"kernel_w"} / (1000*1000);
        }
        elsif($type eq "Pooling"){
            $lr_rlt{"ops"}      = ($lr_info{"channel_out"} * $lr_info{"height_out"} * $lr_info{"width_out"} * $lr_info{"kernel_h"} * $lr_info{"kernel_w"}) / (1000*1000);
            $lr_rlt{"weight"}   = 0;
        }
        elsif($type eq "Eltwise"){
            $lr_rlt{"ops"}      = ($lr_info{"channel_out"} * $lr_info{"height_out"} * $lr_info{"width_out"}) / (1000*1000);
            $lr_rlt{"weight"}   = 0;
            $lr_rlt{"data_in"}  = 2 * $lr_rlt{"data_in"};
        }
        $lr_rlt{"mem_access"} = $lr_rlt{"data_in"} + $lr_rlt{"data_out"} + $lr_rlt{"weight"};
        $net_rlt{$lr_name} = \%lr_rlt;
    }

    my %sum_all;
    $sum_all{"name"} = "sum_all";
    $sum_all{"type"} = "none";
    $sum_all{"ops"} = 0;
    $sum_all{"weight"} = 0;
    $sum_all{"data_in"} = 0;
    $sum_all{"data_out"} = 0;
    $sum_all{"mem_access"} = 0;
    foreach(keys(%net_rlt)){
        my %lr_info = %{$net_rlt{$_}};
        $sum_all{"ops"}      += $lr_info{"ops"};
        $sum_all{"weight"}   += $lr_info{"weight"};
        $sum_all{"data_in"}  += $lr_info{"data_in"};
        $sum_all{"data_out"} += $lr_info{"data_out"};
        $sum_all{"mem_access"} += $lr_info{"mem_access"};
    }
    $net_rlt{"sum_all"} = \%sum_all;

    my %sum_conv;
    $sum_conv{"name"} = "sum_conv";
    $sum_conv{"type"} = "none";
    $sum_conv{"ops"} = 0;
    $sum_conv{"weight"} = 0;
    $sum_conv{"data_in"} = 0;
    $sum_conv{"data_out"} = 0;
    $sum_conv{"mem_access"} = 0;
    foreach(keys(%net_rlt)){
        my %lr_info = %{$net_rlt{$_}};
        if($lr_info{"type"} eq "Convolution"){
            $sum_conv{"ops"}      += $lr_info{"ops"};
            $sum_conv{"weight"}   += $lr_info{"weight"};
            $sum_conv{"data_in"}  += $lr_info{"data_in"};
            $sum_conv{"data_out"} += $lr_info{"data_out"};
            $sum_conv{"mem_access"} += $lr_info{"mem_access"};
        }
    }
    $net_rlt{"sum_conv"} = \%sum_conv;

    my %sum_pool;
    $sum_pool{"name"} = "sum_pool";
    $sum_pool{"type"} = "none";
    $sum_pool{"ops"} = 0;
    $sum_pool{"weight"} = 0;
    $sum_pool{"data_in"} = 0;
    $sum_pool{"data_out"} = 0;
    $sum_pool{"mem_access"} = 0;
    foreach(keys(%net_rlt)){
        my %lr_info = %{$net_rlt{$_}};
        if($lr_info{"type"} eq "Pooling"){
            $sum_pool{"ops"}      += $lr_info{"ops"};
            $sum_pool{"weight"}   += $lr_info{"weight"};
            $sum_pool{"data_in"}  += $lr_info{"data_in"};
            $sum_pool{"data_out"} += $lr_info{"data_out"};
            $sum_pool{"mem_access"} += $lr_info{"mem_access"};
        }
    }
    $net_rlt{"sum_pool"} = \%sum_pool;

    my %sum_dwconv;
    $sum_dwconv{"name"} = "sum_dwconv";
    $sum_dwconv{"type"} = "none";
    $sum_dwconv{"ops"} = 0;
    $sum_dwconv{"weight"} = 0;
    $sum_dwconv{"data_in"} = 0;
    $sum_dwconv{"data_out"} = 0;
    $sum_dwconv{"mem_access"} = 0;
    foreach(keys(%net_rlt)){
        my %lr_info = %{$net_rlt{$_}};
        if($lr_info{"type"} eq "DepthWiseConv"){
            $sum_dwconv{"ops"}      += $lr_info{"ops"};
            $sum_dwconv{"weight"}   += $lr_info{"weight"};
            $sum_dwconv{"data_in"}  += $lr_info{"data_in"};
            $sum_dwconv{"data_out"} += $lr_info{"data_out"};
            $sum_dwconv{"mem_access"} += $lr_info{"mem_access"};
        }
    }
    $net_rlt{"sum_dwconv"} = \%sum_dwconv;

    my %sum_elew;
    $sum_elew{"name"} = "sum_elew";
    $sum_elew{"type"} = "none";
    $sum_elew{"ops"} = 0;
    $sum_elew{"weight"} = 0;
    $sum_elew{"data_in"} = 0;
    $sum_elew{"data_out"} = 0;
    $sum_elew{"mem_access"} = 0;
    foreach(keys(%net_rlt)){
        my %lr_info = %{$net_rlt{$_}};
        if($lr_info{"type"} eq "Eltwise"){
            $sum_elew{"ops"}      += $lr_info{"ops"};
            $sum_elew{"weight"}   += $lr_info{"weight"};
            $sum_elew{"data_in"}  += $lr_info{"data_in"};
            $sum_elew{"data_out"} += $lr_info{"data_out"};
            $sum_elew{"mem_access"} += $lr_info{"mem_access"};
        }
    }
    $net_rlt{"sum_elew"} = \%sum_elew;

    return \%net_rlt;
}

sub net_dump{
    my %net_rlt = %{$_[0]};
    my %net_parse = %{$_[1]};
    my @name = @{$_[2]};

    printf "%-40s", "name";
    printf "%-18s", "type";
    printf "%-10s", "kernel";
    printf "%-10s", "stride";
    printf "%-10s", "output_c";
    printf "%-10s", "input/M";
    printf "%-10s", "output/M";
    printf "%-10s", "weight/M";
    printf "%-10s", "mem_bw/M";
    printf "%-10s", "ops/M";
    printf "\n";

    push(@name, "sum_conv");
    push(@name, "sum_pool");
    push(@name, "sum_dwconv");
    push(@name, "sum_elew");
    push(@name, "sum_all");
    foreach(@name){
        if(exists($net_rlt{$_})){
            printf "%-40s", $_;
            my %layer_info = %{$net_rlt{$_}};
            printf "%-18s", $layer_info{"type"};
            if(exists($layer_info{"type"}) and ($layer_info{"type"} eq "Convolution" or $layer_info{"type"} eq "DepthWiseConv")) {
                my %layer_parse = %{$net_parse{$_}};
                printf "%-10s", $layer_parse{"kernel_h"}."x".$layer_parse{"kernel_w"};
                printf "%-10s", $layer_parse{"stride_h"}."x".$layer_parse{"stride_w"};
                printf "%-10s", $layer_parse{"num_output"};
            }
            else {
                my $empty = "";
                printf "%-10s", $empty;
                printf "%-10s", $empty;
                printf "%-10s", $empty;
            }
            printf "%-10.03f", $layer_info{"data_in"};
            printf "%-10.03f", $layer_info{"data_out"};
            printf "%-10.03f", $layer_info{"weight"};
            printf "%-10.03f", $layer_info{"mem_access"};
            printf "%-10.03f", $layer_info{"ops"};
            printf "\n";
        }
    }
}

1;
