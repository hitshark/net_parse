#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use NetParse;
use NetConvert;
use NetAnalyze;
use InstrAnalyze;

my $conf_file = "./arch.config";
GetOptions(
    "param=s"  => \$conf_file,
);
open(FIN, '<', $conf_file) or die "could not open $conf_file for $!\n";

# parse the config file
my %input;
my %dpu;
my %ddr;
my %bank;
while(<FIN>){
    if($_ =~ /^\s+net_file_name\s+:\s+([\w\/\._]+)/) { $input{"net_file"} = $1; }
    elsif($_ =~ /^\s+net_instr_dir\s+:\s+([\w\/\._]+)/) { $input{"net_dir"} = $1; }
    elsif($_ =~ /^\s+pixel_parallel\s+:\s+\[(\d+),\s*(\d+),\s*(\d+)\]/) {
        my %tmp;
        $tmp{"min"} = $1;
        $tmp{"max"} = $2;
        $tmp{"step"} = $3;
        $dpu{"pp"} = \%tmp;
    }
    elsif($_ =~ /^\s+channel_in_parallel\s+:\s+\[(\d+),\s*(\d+),\s*(\d+)\]/) {
        my %tmp;
        $tmp{"min"} = $1;
        $tmp{"max"} = $2;
        $tmp{"step"} = $3;
        $dpu{"cin"} = \%tmp;
    }
    elsif($_ =~ /^\s+channel_out_parallel\s+:\s+\[(\d+),\s*(\d+),\s*(\d+)\]/) {
        my %tmp;
        $tmp{"min"} = $1;
        $tmp{"max"} = $2;
        $tmp{"step"} = $3;
        $dpu{"cout"} = \%tmp;
    }
    elsif($_ =~ /^\s+calc_parallel\s+:\s+\[(\d+),\s*(\d+)\]/) {
        my %tmp;
        $tmp{"min"} = $1;
        $tmp{"max"} = $2;
        $dpu{"valid_mac"} = \%tmp;
    }
    elsif($_ =~ /^\s+mac_utilization\s+:\s+([\w\/\._]+)/) { $dpu{"mac_util"} = $1; }
    elsif($_ =~ /^\s+clock_frequency\s+:\s+([\w\/_]+)/) { $dpu{"clk"} = $1; }
    elsif($_ =~ /^\s+bank_depth\s+:\s+([\w\/_]+)/) { $bank{"depth"} = $1; }
    elsif($_ =~ /^\s+image_bank_group\s+:\s+([\w\/_]+)/) { $bank{"fmap_group"} = $1; }
    elsif($_ =~ /^\s+hp_width\s+:\s+([\w\/_]+)/) { $ddr{"hp_width"} = $1; }
    elsif($_ =~ /^\s+double_clock_rate\s+:\s+([\w\/_]+)/) { $ddr{"dclk"} = $1; }
}

# obtain the network information
my ($x, $y) = &NetParse::net_parse($input{"net_file"});
my %net = %{$x};
my @name = @{$y};
my $c = &NetConvert::net_extension(\%net, \@name);
my %net_ext = %{$c};
my $d = &NetConvert::net_aggregation(\%net_ext, \@name);
my %net_aggr = %{$d};
my $e = &NetAnalyze::net_analyze(\%net_aggr);
my %net_rlt = %{$e};

my $k = &InstrAnalyze::net_instr_analyze($input{"net_dir"});
my %layer_mem = %{$k};

# scan the parameter
my %pp = %{$dpu{"pp"}};
my %cin = %{$dpu{"cin"}};
my %cout = %{$dpu{"cout"}};
my %calc_pp = %{$dpu{"valid_mac"}};

my %lr_info = %{$net_rlt{"sum_conv"}};
my $net_ops = $lr_info{"ops"} / 1000;

#my %lr_data = %{$layer_mem{"summary"}};
#my $net_mem_access = $lr_data{"total"} / 1000;
#my $load_weight = $lr_data{"load_weight"} / 1000;

my %lr_data = %{$net_rlt{"sum_all"}};
my $net_mem_access = $lr_data{"mem_access"} / 1000;
my $load_weight = $lr_data{"weight"} / 1000;

my $counter = 1;
my %rlt;
for(my $i=$pp{"min"}; $i<=$pp{"max"}; $i+=$pp{"step"}){
    for(my $j=$cin{"min"}; $j<=$cin{"max"}; $j+=$cin{"step"}){
        for(my $k=$cout{"min"}; $k<=$cout{"max"}; $k+=$cout{"step"}){
            my $calc = 2 * $i * $j * $k;
            if($calc >= $calc_pp{"min"} && $calc <= $calc_pp{"max"} ){
                my $ops = $calc * $dpu{"clk"} / 1000;
                my $frame = $ops * $dpu{"mac_util"} / $net_ops;
                my $ddr_band_width = $ddr{"hp_width"} * $ddr{"dclk"} / 1000;
                my $frame_ddr = $ddr_band_width / $net_mem_access;
                my $frame_ddr_wo_weight = $ddr_band_width / ($net_mem_access - $load_weight);
                my $bank_num = $i * $bank{"fmap_group"} + $k + 1;
                my $bank_mem = $bank_num * $bank{"depth"} * $j / (1024*1024);
                my @tmp = ($i, $j, $k, $bank_num, $bank_mem, $dpu{"clk"}, $ops, $net_ops, $dpu{"mac_util"}, $frame, $ddr_band_width,
                        $net_mem_access, $load_weight, $frame_ddr, $frame_ddr_wo_weight);

                $rlt{$counter} = \@tmp;
                $counter += 1;
            }
        }
    }
}

printf "%-10s", "pixel";
printf "%-10s", "chl_in";
printf "%-10s", "chl_out";
printf "%-10s", "bank_num";
printf "%-13s", "bank_mem/M";
printf "%-10s", "clk/MHz";
printf "%-10s", "ops(G/s)";
printf "%-13s", "net_ops";
printf "%-13s", "util";
printf "%-13s", "frame_mac";
printf "%-13s", "ddr_bw";
printf "%-13s", "net_mem_bw";
printf "%-13s", "net_weight";
printf "%-13s", "frame_ddr";
printf "%-20s", "frame/shared_weight";
printf "\n";

foreach(sort{$a<=>$b} keys %rlt){
    my @tmp = @{$rlt{$_}};
    printf "%-10d", shift @tmp;
    printf "%-10d", shift @tmp;
    printf "%-10d", shift @tmp;
    printf "%-10d", shift @tmp;
    printf "%-13.2f", shift @tmp;
    printf "%-10d", shift @tmp;
    printf "%-10.2f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-13.2f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-13.4f", shift @tmp;
    printf "%-20.4f", shift @tmp;
    printf "\n";
}

