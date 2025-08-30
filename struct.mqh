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
    int kind; //1:BUY 2:SELL
    string comment;
    datetime time;
};

#endif // STRUCT_MQH