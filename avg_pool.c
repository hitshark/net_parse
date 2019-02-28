#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <stdint.h>

#define MAX_BW  (16)

typedef struct{
    uint32_t exp;
    uint32_t mat;
}eval_t;

eval_t* get_eval(uint32_t window, double precision)
{
    double gold = 1.0/(window*window);
    eval_t *rlt;
    if(!(rlt = (eval_t *)malloc(sizeof(eval_t)))){
        printf("malloc error\n");
        exit(-1);
    }
    else{
        rlt->exp = 0;
        rlt->mat = 0;
    }

    uint32_t iter;
    for(iter = 0; iter < MAX_BW; iter++){
        uint32_t tmp = 1<<iter;
        double mul = gold * tmp;
        uint32_t ceil_val = ceil(mul);
        uint32_t flr_val = floor(mul);

        double ceil_rlt = (double)(ceil_val) / tmp;
        double flr_rlt = (double)(flr_val) / tmp;

        if(fabs(ceil_rlt-gold)/(double)gold < precision){
            rlt->exp = iter;
            rlt->mat = ceil_val;
            break;
        }
        if(fabs(flr_rlt-gold)/(double)gold < precision){
            rlt->exp = iter;
            rlt->mat = flr_val;
            break;
        }
    }
    return rlt;
}

int main(void)
{
    const uint32_t window[] = {1,3,5,7,9,11};
    const double precision[] = {0.1, 0.01, 0.001, 0.0001};

    int win_s = sizeof(window)/sizeof(window[0]);
    int pcs_s = sizeof(precision)/sizeof(precision[0]);

    printf("%-23s","precision");
    for(int i=0; i<win_s; i++){
        printf("%-14d", window[i]);
    }
    printf("\n");

    for(int i=0; i<pcs_s; i++){
        printf("%-14g", precision[i]);
        for(int j=0; j<win_s; j++){
            eval_t *rlt = get_eval(window[j], precision[i]);
            printf("%8i/%-5i", rlt->mat, (1<<rlt->exp));
        }
        printf("\n");
    }

    return 0;
}

