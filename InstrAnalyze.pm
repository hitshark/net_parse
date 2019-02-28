#!/usr/bin/perl

# function description
# analyze the instr_ac.txt file from a net, and collect the
# memory access requests;
# interface:
#   (@layer_name, @layer_mem_num) <= net_instr_analyze($indir);

package InstrAnalyze 1.0;

use warnings;
use strict;
use Getopt::Long;
use File::Find;
use File::Basename;
use File::Copy;
use File::Spec;
use Cwd;

# 8*8*8, image group = 2
my $data_bank_end = 16;     # fmap_group * channel_parallel
my $weight_bank_end = 24;   # data_bank_end + channel_parallel

sub layer_mem_require{
    my $file = $_[0];
    open(FIN, '<', $file) or die "cann't open file $file for $!\n";
    my %layer_mem;          # for the amount of DDR access in this layer

    $layer_mem{"load_data"} = 0;
    $layer_mem{"load_weight"} = 0;
    $layer_mem{"load_bias"} = 0;
    $layer_mem{"save_data"} = 0;
    while(<FIN>){
        my $line = $_;
        if($line =~ /^LOAD.*bank_id\s+(\d+)\s+.*length\s+(\d+)\s+channel\s+(\d+)/){
            my $bank_id = $1;
            my $load_num = $2 * $3;
            if($bank_id < $data_bank_end){
                $layer_mem{"load_data"} += $load_num;
            }
            elsif($bank_id < $weight_bank_end){
                $layer_mem{"load_weight"} += $load_num;
            }
            else{
                $layer_mem{"load_bias"} += $load_num;
            }
        }
        elsif($line =~ /^SAVE.*bank_id\s+(\d+)\s+.*length\s+(\d+)\s+channel\s+(\d+)/){
            my $bank_id = $1;
            my $load_num = $2 * $3;
            if($bank_id < $data_bank_end){
                $layer_mem{"save_data"} += $load_num;
            }
            else {die "error: save weight/bais out\n";}
        }
    }
    $layer_mem{"load"} = $layer_mem{"load_data"} + $layer_mem{"load_weight"} + $layer_mem{"load_bias"};
    $layer_mem{"total"} = $layer_mem{"load"} + $layer_mem{"save_data"};
    foreach(keys(%layer_mem)){
        $layer_mem{$_} /= (1000*1000);
    }
    return \%layer_mem;
}

my %net_info;
sub wanted{
    if(-f $_){
        if(!($_ =~ /^\./) && !($File::Find::name =~ /\/\.\w/)){
            my $abs_file = $File::Find::name;
            my $file = $_;
            if($file =~ /instr_ac\.txt/){
                my $tmp = &layer_mem_require($abs_file);
                my %lr_info = %{$tmp};
                if($abs_file =~ /.*\/([\w\d_]+)\/instr_ac\.txt/){
                    my $lr_name = $1;
                    $net_info{$lr_name} = \%lr_info;
                }
            }
        }
    }
}

sub net_instr_analyze{
    my $indir = $_[0];
    my $abs_indir = Cwd::abs_path($indir);
    find(\&wanted, $abs_indir);

    my %sum;
    $sum{"load_data"}   = 0;
    $sum{"load_weight"} = 0;
    $sum{"load_bias"}   = 0;
    $sum{"load"}        = 0;
    $sum{"save_data"}   = 0;
    foreach(keys(%net_info)){
        my %lr_info = %{$net_info{$_}};
        $sum{"load_data"}   += $lr_info{"load_data"};
        $sum{"load_weight"} += $lr_info{"load_weight"};
        $sum{"load_bias"}   += $lr_info{"load_bias"};
        $sum{"load"}        += $lr_info{"load"};
        $sum{"save_data"}   += $lr_info{"save_data"};
        $sum{"total"}       += $lr_info{"total"};
    }
    $net_info{"summary"} = \%sum;
    return \%net_info;
}

sub net_instr_dump{
    my %net_info = %{$_[0]};
    printf "%-32s", "name";
    printf "%-15s", "load_data/M";
    printf "%-15s", "load_weight/M";
    printf "%-15s", "load_bias/M";
    printf "%-15s", "load_total/M";
    printf "%-15s", "save_data/M";
    printf "%-15s", "total/M";
    printf "\n";
    foreach my $name(sort keys %net_info){
        my %lr_info = %{$net_info{$name}};
        printf "%-32s", $name;
        printf "%-15.03f", $lr_info{"load_data"};
        printf "%-15.03f", $lr_info{"load_weight"};
        printf "%-15.06f", $lr_info{"load_bias"};
        printf "%-15.03f", $lr_info{"load"};
        printf "%-15.03f", $lr_info{"save_data"};
        printf "%-15.03f", $lr_info{"total"};
        printf "\n";
    }
}

1;
