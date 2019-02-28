#!/usr/bin/perl

# function description
# reduce the layers in a net to concentrate on the calculation
# it refer to the following work:
#   aggregate the concatenation layers
#   delete the relu/prelu/bn/scale etc. layer
#   handling the layer branch
# interface:
#   (%net_ext)  <= net_extension(%net, @name);
#   (%net_aggr) <= net_aggregation(%net_ext, @name);

package NetConvert 1.0;

use warnings;
use strict;
use POSIX;

sub net_extension{
    my %net = %{$_[0]};             # get the net parameter
    my @layer_name = @{$_[1]};      # get the layer name

    my %net_ext;                    # used to store the extended net information and name

    my %net_tmp;                    # to handle the non-consistent of top/name field
    foreach(@layer_name){
        my $lr_name = $_;
        my %lr_info = %{$net{$lr_name}};
        my $lr_type = $lr_info{"type"};

        if($lr_type eq "Input"){
            $lr_info{"channel_out"} = $lr_info{"channel_in"};
            $lr_info{"height_out"}  = $lr_info{"height_in"};
            $lr_info{"width_out"}   = $lr_info{"width_in"};
            $net_ext{"data"} = \%lr_info;
            $net_tmp{"data"} = \%lr_info;
        }
        else{
            my @lr_bottom = @{$lr_info{"bottom"}};
            my $top = $lr_info{"top"};
            my %lr_info_bottom = %{$net_tmp{$lr_bottom[0]}};
            $lr_info{"channel_in"}  = $lr_info_bottom{"channel_out"};
            $lr_info{"height_in"}   = $lr_info_bottom{"height_out"};
            $lr_info{"width_in"}    = $lr_info_bottom{"width_out"};
            $lr_info{"height_out"}  = $lr_info{"height_in"};
            $lr_info{"width_out"}   = $lr_info{"width_in"};
            $lr_info{"channel_out"} = $lr_info{"channel_in"};

            if(($lr_type eq "Convolution") || ($lr_type eq "Pooling") || ($lr_type eq "DepthWiseConv")){
                $lr_info{"height_out"}  = ceil(($lr_info{"height_in"} + 2*$lr_info{"pad_h"} - $lr_info{"kernel_h"} + 1) / $lr_info{"stride_h"});
                $lr_info{"width_out"}   = ceil(($lr_info{"width_in"} + 2*$lr_info{"pad_w"} - $lr_info{"kernel_w"} + 1) / $lr_info{"stride_w"});
                $lr_info{"channel_out"} = $lr_info{"num_output"};
                if($lr_type eq "Pooling"){
                    $lr_info{"channel_out"}  = $lr_info{"channel_in"};
                }
                if($lr_type eq "DepthWiseConv"){
                    if($lr_info{"channel_in"} != $lr_info{"channel_out"}){
                        die "error: dwconv, channel_in is not equal channel_out\n";
                    }
                }
            }
            elsif($lr_type eq "Concat"){
                shift @lr_bottom;
                foreach(@lr_bottom){
                    my %tmp = %{$net_tmp{$_}};
                    $lr_info{"channel_out"} += $tmp{"channel_out"};
                }
            }
            $net_tmp{$top} = \%lr_info;
            $net_ext{$lr_name} = \%lr_info;
        }
    }
    return \%net_ext;
}

sub net_aggregation{
    my %net = %{$_[0]};             # get the net parameter
    my @layer_name = @{$_[1]};      # get the layer name

    my %net_aggr;                   # used to store the reduced net information and name

    foreach(@layer_name){
        my $lr_name = $_;
        my %lr_info = %{$net{$lr_name}};
        my $lr_type = $lr_info{"type"};
        if(($lr_type eq "Convolution") || ($lr_type eq "Pooling") || ($lr_type eq "DepthWiseConv") || ($lr_type eq "Eltwise")){
            $net_aggr{$lr_name} = \%lr_info;
        }
    }
    return \%net_aggr;
}

1;
