//+------------------------------------------------------------------+
//| struct.mqh                                                      |
//+------------------------------------------------------------------+
#ifndef STRUCT_MQH
#define STRUCT_MQH

struct PriceInfoDca
{
    double priceInSignal;
    double volumn;
    double priceDca;
    int kind;
    string comment;
    datetime time;
};

#endif // STRUCT_MQH