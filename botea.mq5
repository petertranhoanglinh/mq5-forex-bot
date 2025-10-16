//+------------------------------------------------------------------+
//|                                                        botea.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
CTrade trade;
input double pfInDay = 100; /// số đô la bạn muốn lợi nhuận trong 1 ngày
input int magicNumber = 765432;
input double lot_size = 0.05;
input double tp_pip = 100;
input double sl_pip = 100;
input double sl_pip_change = 10;

int pinbarsHandle;
double pinUpBuffer[], pinDnBuffer[], arrowUpBuffer[], arrowDnBuffer[];
int OnInit()
  {
    pinbarsHandle = iCustom(Symbol(), Period(), "iPinBars.ex5", 
                          10,    // MinCandleSizePT
                          0.33,  // MaxCandleBodySize  
                          0.33,  // RelativeToPrevCandle
                          2.0);  // AspectRatioShadows
   
   if(pinbarsHandle == INVALID_HANDLE)
   {
      Print("Không thể load chỉ báo PinBars!");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;
bool hasTraded = false;

void OnTick()
{
   datetime currentBar = iTime(_Symbol, _Period, 0);
   double sl = sl_pip * GetPip(_Symbol);
   double tp = tp_pip * GetPip(_Symbol);
   // Reset trạng thái khi có bar mới
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      hasTraded = false;
   }
   
   CopyBuffer(pinbarsHandle, 0, 0, 3, pinUpBuffer); 
   CopyBuffer(pinbarsHandle, 1, 0, 3, pinDnBuffer);  
   CopyBuffer(pinbarsHandle, 2, 0, 3, arrowUpBuffer);
   CopyBuffer(pinbarsHandle, 3, 0, 3, arrowDnBuffer);
   
   bool buySignal = arrowUpBuffer[0] != EMPTY_VALUE;
   bool sellSignal = arrowDnBuffer[0] != EMPTY_VALUE;
   
   // Kiểm tra có position nào không
   bool hasPosition = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
      {
         hasPosition = true;
         break;
      }
   }
   if(!hasTraded && !hasPosition)
   {
      if(buySignal)
      {
         if(openBuy(lot_size,sl, tp, magicNumber, "support for petertranhoanglinh@gmail.com"))
         {
            hasTraded = true;
            Print("✓ Đã vào BUY - ", TimeToString(TimeCurrent()));
         }
      }
      else if(sellSignal)
      {
         if(openSell(lot_size, sl, tp, magicNumber, "support for petertranhoanglinh@gmail.com"))
         {
            hasTraded = true;
            Print("✓ Đã vào SELL - ", TimeToString(TimeCurrent()));
         }
      }
   }
}
  
bool openBuy(double volumn, double stoploss, double takeProfit, int magic , string comment)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = (takeProfit == 0) ? 0 : price + takeProfit;
   double sl = (stoploss == 0) ? 0 : price - stoploss;
   trade.SetExpertMagicNumber(magic);
   if(trade.Buy(volumn, _Symbol, price, sl, tp, comment))
   {
      return true;
   }
   else
   {
      return false;
   }
}

bool openSell(double volumn, double stoploss, double takeProfit, int magic ,  string comment)
{
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = (takeProfit == 0) ? 0 : price - takeProfit;
   double sl = (stoploss == 0) ? 0 : price + stoploss;
   trade.SetExpertMagicNumber(magic);
   if(trade.Sell(volumn, _Symbol, price, sl, tp, comment))
   {
      return true;
   }
   else
   { 
      return false;
   }
}

double GetPip(string symbol = NULL)
{
   if(symbol == NULL)
      symbol = _Symbol;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   return (digits == 3 || digits == 5) ? point * 10 : point;
}

void ModifyPositionByTicket(ulong ticket, double newSL, double newTP)
{
    if(!PositionSelectByTicket(ticket))
    {
        Print("❌ Ticket not found: ", ticket);
        return;
    }
    string symbol = PositionGetString(POSITION_SYMBOL);
    // Chuẩn bị request
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);
    request.action   = TRADE_ACTION_SLTP; 
    request.position = ticket;            
    request.symbol   = symbol;
    request.sl       = newSL;
    request.tp       = newTP;
    // Gửi lệnh modify
    if(!OrderSend(request, result))
        Print("❌ Failed modify ticket=", ticket, " | Error=", GetLastError());
    else
        Print("✅ Updated ticket=", ticket, " | SL=", newSL, " | TP=", newTP, 
              " | Retcode=", result.retcode);
}

double getCurrentPrice(int type){
   double currentPrice;
   if(type == POSITION_TYPE_BUY)
       currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   else
       currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return currentPrice;
}

void traddingSl()
{
     for(int i = 0 ; i <  PositionsTotal() ; i ++ ){
           ulong ticket = PositionGetTicket(i);
           int positionMagic = PositionGetInteger(POSITION_MAGIC);
           double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
           double sl = PositionGetDouble(POSITION_SL);
           int typePosition = PositionGetInteger(POSITION_TYPE);
           if(magicNumber == positionMagic){
               if(sl == 0)
               {
                  if(typePosition == POSITION_TYPE_BUY)
                  {
                    double currentPrice = getCurrentPrice(POSITION_TYPE_BUY);
                    if((currentPrice - openPrice) * GetPip(_Symbol) > tp_pip)
                    {
                      double sl = (currentPrice - openPrice) * GetPip(_Symbol) - sl_pip_change;
                      ModifyPositionByTicket(ticket,sl,0);
                    }
                  }else{
                    double currentPrice = getCurrentPrice(POSITION_TYPE_SELL);
                    if((openPrice - currentPrice) * GetPip(_Symbol) > tp_pip)
                    {
                      double sl = (openPrice - currentPrice) * GetPip(_Symbol) - sl_pip_change;
                      ModifyPositionByTicket(ticket,sl,0);
                    }
                  }
               }
           }
      }
   
}
