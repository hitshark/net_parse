#include <vector>
#include <string>
#include <valarray>
#include <iostream>
#include <iomanip>
#include <glog/logging.h>

// load execution path
// dispatch -> ddr -> reshape -> write bank
// conv execution path
// dispatch -> read bank -> calculation

/* parameters need to be considered:
 * input channel: [1,3,4]
 * kernel size  : [3,5,7]
 * stride       : [1,2,3]
 * trans_size   : 64Byte * burst_length
 * dispatch_latency : 10 cycle
 * ddr_latency      : 64Byte/cycle
 * reshape_latency  : 1 bank_entry/cycle
 * bank_write       : no conflict
 */

static int dispatch_latency = 0;    // first load dispatch latency
static int ddr_latency      = 0;    // first ddr request done
static int reshape_latency  = 1;    // one bank entry
static int trans_size       = 2560;

typedef struct{
    int load_lt;
    int mac_lt;
    int load_lt_aug;
    int mac_lt_aug;
}lt_t;

// for 4*8*16 parallelism
lt_t load_eval(int channel_in, int kernel_size, int stride, int trans_size, int channel_out)
{
    int pixel_num = std::ceil((double)trans_size/channel_in);
    //int src_h = (4-1) * stride + kernel_size;
    int src_h = 4 * stride;     // average value
    int length = (pixel_num - kernel_size) / stride + 1;
    int reshape_lt = pixel_num * src_h * reshape_latency * std::ceil(channel_in/8.0);

    int load_latency = dispatch_latency + ddr_latency + reshape_lt;
    int mac_latency = length * kernel_size * kernel_size * (channel_out/16) * std::ceil(channel_in/8.0);

    int channel_aug = channel_in * kernel_size;
    int channel_group = std::ceil(channel_aug / 8.0);
    //int pixel_aug = std::ceil(double(trans_size) / channel_aug) * channel_group;
    int reshape_lt_aug = (length+kernel_size-1) * src_h * channel_group * reshape_latency;
    //int reshape_lt_aug = pixel_num * src_h * channel_group * reshape_latency;

    int load_latency_aug = dispatch_latency + ddr_latency + reshape_lt_aug;
    int mac_latency_aug = length * kernel_size * channel_group * (channel_out/16);

    lt_t tmp = {load_latency, mac_latency, load_latency_aug, mac_latency_aug};
    return tmp;
}

int main(int argc, char *argv[])
{
    using std::vector;
    using std::cout;
    using std::endl;
    using std::setfill;
    using std::setw;

    //vector<int> channel_in = {1,3,4};
    vector<int> channel_in = {256, 512, 1024};
    //vector<int> kernel = {3,5,7};
    vector<int> kernel = {1,3};
    //vector<int> stride = {1,2,3};
    vector<int> stride = {1,2};
    vector<int> channel_out = {64};

    cout << setfill(' ')
        << setw(15) << "channel_in"
        << setw(15) << "kernel_size"
        << setw(15) << "stride"
        << setw(15) << "channel_out"
        << setw(15) << "trans_size"
        << setw(15) << "load_cycle"
        << setw(15) << "calc_cycle"
        << setw(15) << "load/calc"
        << setw(15) << "aug_load_cycle"
        << setw(15) << "aug_calc_cycle"
        << setw(15) << "aug load/calc"
        << endl
        << "----------------------------------------------------------------------------------"
        << "----------------------------------------------------------------------------------"
        << endl;
    for(auto i = channel_in.begin(); i != channel_in.end(); i++) {
        for(auto j = kernel.begin(); j != kernel.end(); j++) {
            for(auto k = stride.begin(); k != stride.end(); k++) {
                for(auto l = channel_out.begin(); l != channel_out.end(); l++) {
                    lt_t rlt = load_eval(*i, *j, *k, trans_size, *l);
                    cout << setfill(' ')
                        << setw(15) << *i
                        << setw(15) << *j
                        << setw(15) << *k
                        << setw(15) << *l
                        << setw(15) << trans_size
                        << setw(15) << rlt.load_lt
                        << setw(15) << rlt.mac_lt
                        << setw(15) << std::fixed << std::setprecision(2) << ((double)rlt.load_lt/rlt.mac_lt)
                        << setw(15) << rlt.load_lt_aug
                        << setw(15) << rlt.mac_lt_aug
                        << setw(15) << std::fixed << std::setprecision(2) << ((double)rlt.load_lt_aug/rlt.mac_lt_aug)
                        << endl;
                }

            }
        }
    }
    return 0;
}

