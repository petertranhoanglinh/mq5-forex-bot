//+------------------------------------------------------------------+
//|                                                  bot_bitcoin.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "TRAN HOANG LINH BOT DCA"
#property link      "petertranhoanglinh@gmail.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
CTrade trade;
input group "__Set Các chức năng liên quan tới BUY DCA ÂM"; 
input double lotBuyAm = 0.01; // Số lot vào lệnh 
input double dcaBuyPriceAm = 3; // khoảng giá DCA BUY Âm
input double tpBuyAm = 3; //  Tp cho DCA BUY ÂM
input bool  isDcaBuyAm = true; // BẬT/ TẮT

input group "__Set Các chức năng liên quan tới SELL DCA ÂM"; 
input double lotSellAm = 0.01; // Số lot vào lệnh 
input double dcaSellPriceAm = 3; // khoảng giá DCA BUY Âm
input double tpSellAm = 3;   //  Tp cho DCA SELL ÂM
input bool  isDcaSellAm = true; // BẬT/ TẮT


input group "__Set Các chức năng liên quan tới BUY DCA DƯƠNG"; 
input double lotBuyDuong = 0.03; // Số lot vào lệnh 
input double dcaPriceBuyDuong = 0.3; // khoảng giá DCA BUY DƯƠNG
input double tpBuyDcaDuong  = 0;
input bool  isDcaBuyDuong = true; // BẬT/ TẮT

input group "__Set Các chức năng liên quan tới SELL DCA DƯƠNG"; 
input double lotSellDuong = 0.03; // Số lot vào lệnh 
input double dcaPriceSellDuong = 0.3;// khoảng giá DCA SELL DƯƠNG
input double tpSellDcaDuong  = 0;
input bool  isDcaSellDuong = true; // BẬT/ TẮT



input group "_Dời SL TP DCA DƯƠNG NÂNG CAO"; 
input double tp_sl_dca_duong = 50; // lợi nhuận nếu tổng DCA dương đạt tới sẽ dời SL
input double checkProfitClose = 100; // Lợi nhuận tổng để đóng DCA DƯƠNG
input double new_tp_dca_duong = 10; // dời sl tp khi đổi trend
input double new_sl_dca_duong = 10; // dời sl tp khi đổi trend

input group "_Dời SL_TP DCA ÂM NÂNG CAO"; 
input double new_tp_dca_am = 10;
input double new_sl_dca_am = 10;


input group "_Option tia dca âm dương";
input bool is_tia_dca_duong = true; // bật tắt chức năng tỉa dca dương
input bool is_tia_dca_am = true; // bật tắt chức năng tỉa dca âm
input double profitLostPram = -50; // set lệnh nếu profit nhỏ hơn sẽ dời sl theo tín hiệu rsi

input group "_Option chức năng giới hạn order limit";
input ENUM_TIMEFRAMES timeFrames = PERIOD_H1;// Khoảng thời gian giới hạn order
input double inputLimit = 60; // số lần giới hạn order
input bool istradinggood = true; // bạn đang áp dụng cho vàng
 
// -------------------------
// ⚙️ Cài đặt nâng cao khi bot gặp sự cố
// -------------------------
input group "_Search app telegram flow_bot_dca_linhlinh nhấn /start)"; 
input string t_code_telegram = "1180457993";// 📩 Nhập chatID Telegram (/start search bot @userinfobot get id) 
input int serverOffSet = 7; // ⏰ Nhập chênh lệch server
input double drawdownSendMessage = 20;// 📩 Nhập % drawdown bot sẽ message 
input bool isShutDownBotIsFail = false;// chỉ nên bật ngày fed công bố lãi suất

int magicNumberDuong = 1234567;
int magicNumberAm = 54321;
int magicNumberHedge = 02231;
double countProfit = 0;
bool flagBotActive = true;
long static countLimit; 
datetime static timeCheckOrderLimit = TimeCurrent();

datetime timelastedSendTelegram = 0;
datetime time_check_sp_tp_dca_am = 0;

int halfTrendHandle;
int    InpAmplitude   = 5;     // Amplitude
uchar  InpCodeUpArrow = 233;   // Arrow code for 'UpArrow' (Wingdings)
uchar  InpCodeDnArrow = 234;   // Arrow code for 'DnArrow' (Wingdings)
int    InpShift       = 10;    // Vertical shift of arrows
int halfTrend = 0;

double static priceCheckResetBot = 10000;
double price_for_reset = 1000;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   halfTrendHandle = iCustom(_Symbol, _Period, 
                             "HalfTrend",  
                             InpAmplitude,
                             InpCodeUpArrow,
                             InpCodeDnArrow,
                             InpShift);
   if(halfTrendHandle == INVALID_HANDLE)
   {
      Print("❌ Không load được Half Trend New. Lỗi: ", GetLastError());
      return(INIT_FAILED);
   }
   countLimit = 0;
   priceCheckResetBot = AccountInfoDouble(ACCOUNT_EQUITY);
   timeCheckOrderLimit = TimeCurrent();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!flagBotActive)
    {
      SendTelegramMessage("BOT FAIL FOR ACCOUNT: "+AccountInfoInteger(ACCOUNT_LOGIN)+" "+AccountInfoString(ACCOUNT_NAME)+GetTimeVN() , true);
      if(isShutDownBotIsFail)
      {
        return;
      }
    }
    
     if(!isMarketOpen() && istradinggood)
    {
        
        Print("MARKET CLOSE BOT SHUTDOWN, " , GetTimeVN());
        return;
    }
    resetBot();
    bool flagDisableDcaDuong = false;
    if(isSideway(PERIOD_M15)){
      Print("THỊ TRƯỜNG SIDE WAY");
      flagDisableDcaDuong = true;
    }
    datetime signalTime;// đánh giấu thới gian ghi nhận có tín hiệu 
    double signalPrice;
    static datetime lastSignalTime = 0;
        
     
    int signal = GetHalfTrendSignal(signalTime, signalPrice);
    if(signalTime > lastSignalTime && signal != 0)
    {
      lastSignalTime = signalTime;
      halfTrend = signal;
    }
    
    if(TimeCurrent() - signalTime >  60*60*5 && signal == 0)
    {
      halfTrend = 0;
    }
    double rsi = CalculateRSI(14 ,  PERIOD_H1);
    double minPriceBuy = DBL_MAX;
    double hightPriceBuyDuong =  0;
    double lowPriceSellDuong = DBL_MAX;
    double hightPriceSELL = 0;
    int totalPositonBUY = 0;
    int totalPositonSELL = 0;
    double profitBuyDuong = 0;
    double profitSellDuong = 0;
    double profitTrend = 0;
    // avairable âm
    double minPriceBuyAm = DBL_MAX;
    double hightPriceSellAm = 0;
    int totalPositonAmBUY = 0;
    int totalPositonAmSELL = 0;
    
    int total_dca_buy_duong_flow_trend = 0;
    int total_dca_sell_duong_flow_trend = 0;
    double high_buy_dca_duong_flow_trend = 0;
    double low_sell_dca_duong_flow_trend = DBL_MAX;
    for(int i = 0 ; i <  PositionsTotal() ; i ++ ){
         ulong ticket = PositionGetTicket(i);
         int typePosition = PositionGetInteger(POSITION_TYPE);
         int positionMagic = PositionGetInteger(POSITION_MAGIC);
         double pricePosition = PositionGetDouble(POSITION_PRICE_OPEN);
         double volumn = PositionGetDouble(POSITION_VOLUME);
         string comment  = PositionGetString(POSITION_COMMENT);
         datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(magicNumberDuong == positionMagic && comment != "TREND")
         {
            if(typePosition == POSITION_TYPE_BUY){
               totalPositonBUY ++ ; 
               if (pricePosition < minPriceBuy){
                  minPriceBuy = pricePosition;
               }
               if(pricePosition > hightPriceBuyDuong ){
                  hightPriceBuyDuong = pricePosition;
               }
               profitBuyDuong = profitBuyDuong + profit;
               
            }else {
               totalPositonSELL++ ; 
               if(pricePosition > hightPriceSELL){
                  hightPriceSELL = pricePosition;
               }
               if(pricePosition < lowPriceSellDuong){
                  lowPriceSellDuong = pricePosition;
               }
                profitSellDuong = profitSellDuong + profit;
            }
         }
         if(magicNumberDuong == positionMagic)
         {
            if(typePosition == POSITION_TYPE_BUY){
              total_dca_buy_duong_flow_trend ++;
              if(pricePosition > high_buy_dca_duong_flow_trend ){
                  high_buy_dca_duong_flow_trend = pricePosition;
              }
               
            }else {
              total_dca_sell_duong_flow_trend ++;
              if(pricePosition < low_sell_dca_duong_flow_trend){
                  low_sell_dca_duong_flow_trend = pricePosition;
              }
            }
            profitTrend = profitTrend + profit;
         }
         
         if(magicNumberAm == positionMagic)
         {
            if(typePosition == POSITION_TYPE_BUY){
               totalPositonAmBUY ++ ; 
               if(pricePosition < minPriceBuyAm){
                  minPriceBuyAm = pricePosition;
               }
            }else{
               totalPositonAmSELL ++ ;
               if(pricePosition > hightPriceSellAm){
                  hightPriceSellAm = pricePosition;
               }
            }
         }
     }
     // DCA DƯƠNG
     ShowReport(minPriceBuyAm , hightPriceSellAm , lowPriceSellDuong , hightPriceBuyDuong);
    
     if(totalPositonBUY == 0 && totalPositonSELL == 0)
     {
        double avgPrice = MA_Custom(_Symbol ,PERIOD_M5 , 14);
        if(isDcaBuyDuong && SymbolInfoDouble(_Symbol, SYMBOL_ASK) - avgPrice > dcaPriceBuyDuong)
        {
          flagBotActive = openBuy(lotBuyDuong , 0 , tpBuyDcaDuong , magicNumberDuong , "BUY +|  "  + IntegerToString(totalPositonBUY) + " AT: " + GetTimeVN() );
        }
        if(isDcaSellDuong && avgPrice - SymbolInfoDouble(_Symbol, SYMBOL_BID) > dcaPriceSellDuong)
        {
          flagBotActive = openSell(lotSellDuong , 0 , tpSellDcaDuong , magicNumberDuong , "SELL +|  "  + IntegerToString(totalPositonSELL) + " AT: " + GetTimeVN());
        }
        
     }else{
         
         if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - hightPriceBuyDuong > dcaPriceBuyDuong && isDcaBuyDuong && halfTrend != -1 && flagDisableDcaDuong == false)
         {
              double volum = lotBuyDuong ;
              if(halfTrend == 1){
                volum = lotBuyDuong  * 3;
              }
             flagBotActive = openBuy(volum , 0 , 0 , magicNumberDuong , "BUY +| "  + IntegerToString(totalPositonBUY) + " AT: " + GetTimeVN());   
         }
         if(lowPriceSellDuong - SymbolInfoDouble(_Symbol, SYMBOL_BID) >  dcaPriceSellDuong && isDcaSellDuong && halfTrend != 1 && flagDisableDcaDuong == false){
              double volum = lotSellDuong ;
              if(halfTrend == -1){
                volum = lotSellDuong  * 3;
              }
             flagBotActive = openSell(volum, 0 , 0 , magicNumberDuong , "SELL +| "  + IntegerToString(totalPositonSELL) + " AT: " + GetTimeVN());
         }
         
         if(profitBuyDuong + profitSellDuong + profitTrend > checkProfitClose)
         {
            flagBotActive = CloseAllBuyPositions(magicNumberDuong);
            flagBotActive = CloseAllSellPositions(magicNumberDuong);
         }
     }
     // DCA ÂM
     if(totalPositonAmBUY == 0 && totalPositonAmSELL == 0)
     {
         
         if(isDcaBuyAm)
         {
            flagBotActive = openBuy(lotBuyAm , 0 , tpBuyAm , magicNumberAm , "BUY -|  "  + IntegerToString(totalPositonAmBUY) + " AT: " + GetTimeVN());
         }
         
         if(isDcaSellAm)
         {
             flagBotActive = openSell(lotSellAm , 0 , tpSellAm , magicNumberAm , "SELL -|  "  + IntegerToString(totalPositonAmSELL) + " AT: " + GetTimeVN());
         }
      
     }else{
         if(minPriceBuyAm - SymbolInfoDouble(_Symbol, SYMBOL_ASK) >  dcaBuyPriceAm && isDcaBuyAm)
         {
           
           flagBotActive = openBuy(lotBuyAm , 0 , tpBuyAm , magicNumberAm , "BUY -|  "  + IntegerToString(totalPositonAmBUY) + " AT: " + GetTimeVN()); 
         }
         
         if(SymbolInfoDouble(_Symbol, SYMBOL_BID) - hightPriceSellAm > dcaSellPriceAm && isDcaSellAm && halfTrend != 1)
         {
           
           flagBotActive = openSell(lotSellAm , 0 , tpSellAm , magicNumberAm , "SELL -|  "  + IntegerToString(totalPositonAmSELL) + " AT: " + GetTimeVN());
         }
     }
     
    
    if(is_tia_dca_duong){
      calculator_Sl_Dca_Duong();
    }
    if((TimeCurrent() - time_check_sp_tp_dca_am) >= 60*5)
    {
        time_check_sp_tp_dca_am = TimeCurrent();
        if(is_tia_dca_am){
          calculator_Sl_Dca_Am();
        }
    }
    
     if((TimeCurrent() - timelastedSendTelegram) > 5)
     {
        // update telegram before
          
    }
   
}


// --------------------------------------------------logic bot function----------------------------------------------------------------------------------------------------------------

void calculator_Sl_Dca_Duong(){
   ulong arrWin[];
   ulong arrLost[];
   double profit = 0;
   double percent_tia_lenh = 0.2;
   bool haveSLBuy = false;
   bool haveSLSell = false;
   int totalBuy = 0;
   int totalSell = 0;
   
   
   for(int i = 0 ; i < PositionsTotal() ; i++)
    {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        
        double sl = PositionGetDouble(POSITION_SL);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberDuong && PositionGetString(POSITION_COMMENT) != "TREND"){        
               profit = profit + profitPostion;
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  totalBuy ++ ;
               }else
               {
                  totalSell ++ ;
               }
               if(profitPostion > 0)
               {
                  AddToArray(arrWin, ticket);
                 
               }
               if(profitPostion < profitLostPram){
                 AddToArray(arrLost, ticket);
                 if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sl != 0)
                 {
                  haveSLBuy = true;
                 }
                 if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && sl != 0){
                  haveSLSell = true;
                 }
                 
               }
            }
           
        }
    }
   
    if(profit > tp_sl_dca_duong)
    {
       // update sl
       for(int i = 0; i < ArraySize(arrWin); i++)
       {
         ulong ticket = arrWin[i];
         double currentPrice;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(PositionSelectByTicket(ticket)){
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            double volumn =  PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double newSl = 0;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               newSl = openPrice  +  ((currentPrice - openPrice) / 2);
            }else{
               newSl = openPrice  - ((openPrice - currentPrice) / 2);
            }
            Print("TICKET CẦN TP LÀ: ", ticket );
            Print("SL : ", newSl);
            Print("TYPE : ", PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ? "SELL" : "BUY");
            if(sl == 0 &&  newSl != 0)
            {
              ModifyPositionByTicket(ticket , newSl , 0);
            }
           
         }
         
       }
    }
    
   double rsi = CalculateRSI(14 ,  PERIOD_M15);
   int type = 0;
   if(rsi< 40)
      {
         type = 1;
      }
      if(rsi > 60)
      {
         type = -1;
   }
   if(isSideway(PERIOD_M15))
   {
      if(rsi < 50)
      {
         type = 1;
      }
      
      if(rsi > 50)
      {
         type = -1;
      }
      
   }
   
   // cắt lô
   int limitLenhTia =  int(arrLost.Size() * percent_tia_lenh); 
   int countTiaLenh = 0;
   if(type != 0)
   {
     for(int i = 0; i < ArraySize(arrLost); i++)
     {
         ulong ticket = arrLost[i];
         double currentPrice;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(PositionSelectByTicket(ticket)){
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volumn =  PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double newSl = 0;
            double newTp = 0;
            double distanceIn1Price = volumn / 0.01 ;
           
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && type == 1 && haveSLSell == false)
            {
               newSl = currentPrice + (new_sl_dca_duong / distanceIn1Price);
               newTp = currentPrice - (new_tp_dca_duong / distanceIn1Price);
            }
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && type == -1 && haveSLBuy == false)
            {
               newSl = currentPrice - (new_sl_dca_duong / distanceIn1Price);
               newTp = currentPrice + (new_tp_dca_duong / distanceIn1Price);
            
            }
            Print("TP: ", newTp);
            Print("SL : ", newSl);
            Print("CR : ", currentPrice);
            Print("TYPE : ", PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ? "SELL" : "BUY");
            if(sl == 0 && newSl !=0 && newTp != 0 && countTiaLenh < limitLenhTia)
            {
              ModifyPositionByTicket(ticket , newSl , newTp);
              countTiaLenh ++ ;
            }
            
         }
   
      }
   }
}

void calculator_Sl_Dca_Am(){
   ulong arrLost[];
   double profit = 0;
   double percent_tia_lenh = 0.2;
   bool haveSLBuy = false;
   bool haveSLSell = false;
   for(int i = 0 ; i < PositionsTotal() ; i++)
   {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        double sl = PositionGetDouble(POSITION_SL);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberAm){        
               profit = profit + profitPostion;
               if(profitPostion < profitLostPram)
               {
                 AddToArray(arrLost, ticket);
                 if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sl != 0)
                 {
                  haveSLBuy = true;
                 }
                 if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && sl != 0){
                  haveSLSell = true;
                 }
               }
            }
        }
    }
    double rsi = CalculateRSI(14 ,  PERIOD_M15);
    int type = 0;
    int limitLenhTia =  int(arrLost.Size() * percent_tia_lenh); 
    int countTiaLenh = 0;
    
    if(rsi< 40)
    {
      type = 1;
    }
    if(rsi > 60 )
    {
      type = -1;
    }
    
    if(isSideway(PERIOD_M15) && type == 0)
   {
      if(rsi < 50)
      {
         type = 1;
      }
      
      if(rsi > 50)
      {
         type = -1;
      }
      
   }
    if(type != 0) // giá tăng dời sl cho lệnh sell thôi
    {
       for(int i = 0; i < ArraySize(arrLost); i++)
       {
         ulong ticket = arrLost[i];
        
         double currentPrice;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(PositionSelectByTicket(ticket)){
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volumn =  PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double newSl = 0;
            double newTp = 0;
            double distanceIn1Price = volumn / 0.01 ;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && type == 1 && haveSLSell ==  false)
            {
               newSl = currentPrice + (new_sl_dca_am / distanceIn1Price);
               newTp = currentPrice - (new_sl_dca_am / distanceIn1Price);
            }
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && type == -1 && haveSLBuy == false){
               newSl = currentPrice - (new_sl_dca_am / distanceIn1Price);
               newTp = currentPrice + (new_sl_dca_am / distanceIn1Price);
            }
            Print("TICKET CẦN SL LÀ: ", ticket);
            Print("TP: ", newTp);
            Print("SL : ", newSl);
            Print("CR : ", currentPrice);
            Print("TYPE : ", PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ? "SELL" : "BUY");
            if(sl == 0 && newSl != 0 && newTp != 0 && countTiaLenh < limitLenhTia)
            {
              ModifyPositionByTicket(ticket , newSl , newTp);
              countTiaLenh ++ ;
            }
           
         }
         
       }
    }
    
    
}
// --------------------------------------------------end logic bot function----------------------------------------------------------------------------------------------------------------


// --------------------------------------------------common function---------------------------------------------------------------------------------------------------------------

bool openBuy(double volumn, double stoploss, double takeProfit, int magic , string comment)
{
   if(!checkOrderLimit(timeFrames , inputLimit))
   {
      Print("Limit Order Accept");
      return true;
   }
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = (takeProfit == 0) ? 0 : price + takeProfit;
   double sl = (stoploss == 0) ? 0 : price - stoploss;
   
   trade.SetExpertMagicNumber(magic);
   Print(" --------------------------------ORDER " + comment+" -----------------------------------------" );
   Print("PRICE: " , price);
   Print("TP: " , tp);
   Print("SL: " , sl);
   Print(" ---------------------------------------------------------------------------------------------" );
   if(trade.Buy(volumn, _Symbol, price, sl, tp, comment))
   {
      Print(" --------------------------------SEND BUY SUCCESS " + comment +" -----------------------------------------" );
      return true;
   }
   else
   {
      Print(" --------------------------------SEND BUY ERROR " + comment + " -----------------------------------------" );
      return false;
   }
}

bool openSell(double volumn, double stoploss, double takeProfit, int magic ,  string comment)
{
   if(!checkOrderLimit(timeFrames , inputLimit))
   {
      Print("Limit Order Accept");
      return true;
   }
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = (takeProfit == 0) ? 0 : price - takeProfit;
   double sl = (stoploss == 0) ? 0 : price + stoploss;
   Print(" --------------------------------ORDER " + comment +" -----------------------------------------" );
   Print("PRICE: " , price);
   Print("TP: " , tp);
   Print("SL: " , sl);
   Print(" ---------------------------------------------------------------------------------------------" );
   trade.SetExpertMagicNumber(magic);
   if(trade.Sell(volumn, _Symbol, price, sl, tp, comment))
   {
      Print(" --------------------------------SEND SELL SUCCESS " + comment + " -----------------------------------------" );
      return true;
   }
   else
   { 
      Print(" --------------------------------SEND SELL SUCCESS " + comment + " -----------------------------------------" );
      return false;
   }
}

bool CloseAllBuyPositions(int magic = -1)
{
    bool result = true;
    int totalClosed = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
               (magic == -1 || PositionGetInteger(POSITION_MAGIC) == magic))
            {
                if(trade.PositionClose(ticket))
                {
                    totalClosed++;
                    Print(" --------------------------------CLOSE BUY ORDER SUCCESS " + ticket + " AT " + GetTimeVN() +" -----------------------------------------" );
                }
                else
                {
                    Print(" --------------------------------CLOSE BUY ORDER ERROR" + ticket + " AT " + GetTimeVN() +" -----------------------------------------" );
                    result = false;
                }
            }
        }
    }
    Print(" --------------------------------CLOSE BUY ORDER SUCCESS COUNT " + totalClosed + " AT " + GetTimeVN() +" -----------------------------------------" );
    return result;
}

bool CloseAllSellPositions(int magic = -1)
{
    bool result = true;
    int totalClosed = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
               (magic == -1 || PositionGetInteger(POSITION_MAGIC) == magic))
            {
                if(trade.PositionClose(ticket))
                {
                    totalClosed++;
                     Print(" --------------------------------CLOSE SELL ORDER SUCCESS " + ticket + " AT " + GetTimeVN() +" -----------------------------------------" );
                }
                else
                {
                     Print(" --------------------------------CLOSE SELL ORDER ERROR" + ticket + " AT " + GetTimeVN() +" -----------------------------------------" );
                    result = false;
                }
            }
        }
    }
    Print(" --------------------------------CLOSE SELL ORDER SUCCESS COUNT " + totalClosed + " AT " + GetTimeVN() +" -----------------------------------------" );
    return result;
}

// Hàm kiểm tra thị trường vàng có đang mở không
bool isMarketOpen()
{
   datetime now = TimeTradeServer();   // lấy thời gian server của broker
   MqlDateTime tm;
   TimeToStruct(now, tm);

   int dayOfWeek = tm.day_of_week;     // 0 = Chủ nhật, 1 = Thứ 2, ..., 6 = Thứ 7
   int hour      = tm.hour;
   int minute    = tm.min;
   if(dayOfWeek == 0) return false;
   if(dayOfWeek == 6 && hour >= 23 && minute >= 59) return false;  
   if(dayOfWeek == 5 && hour >= 23 && minute >= 59) return false; 
   if(hour == 23 && minute >= 59) return false;  
   if(hour == 0  && minute < 5) return false;

   return true;
}



// Trả về giờ Việt Nam (string dạng 24h HH:MM:SS)
string GetTimeVN()
{
   // Giờ server
   datetime nowServer = TimeCurrent();
   // Giờ Việt Nam (server offset * 3600 giây)
   datetime vnTime = nowServer + serverOffSet * 3600;
   // Trả về dạng 24h
   return TimeToString(vnTime, TIME_DATE | TIME_SECONDS);
}


bool SendTelegramMessage(string text , bool disableNotification = false)
{
   string token  = "7542004417:AAF43NYwPUG3p9i3CWjXMV6j1C_qIrfZHhM";
   string url  = "https://api.telegram.org/bot" + token + "/sendMessage";
  
   string data = "chat_id=" +t_code_telegram + "&text=" + text;
   if(disableNotification == false){
      data = data + "&disable_notification=false";
   }
   char post[];
   StringToCharArray(data, post);
   char result[];
   string headers;
   int timeout = 5000; // 5 giây
   int res = WebRequest("POST",
                        url,
                        "Content-Type: application/x-www-form-urlencoded\r\n",
                        timeout,
                        post,
                        result,
                        headers);
   if(res == 200)
   {
      return true;
   }
   else
   {
      Print("❌ Telegram send failed. Code=", res, " Response=", CharArrayToString(result));
      return false;
   }
}



void checkDrawDown()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double drawdownCurrent = 0.0;
   if(balance > 0)
      drawdownCurrent = (balance - equity) / balance * 100.0;
   if(drawdownCurrent > drawdownSendMessage)
   {
      SendTelegramMessage("ACCOUNT WARNING PLEASE CHECK! DrawDownCurrent: " + drawdownSendMessage);
   }
}

void ShowReport(double minPriceBuyAmParam , double hightPriceSellAmParam , double lowPriceSellDuongParam , double hightPriceBuyDuongParam)
{
   int startY = 20; // Vị trí bắt đầu từ trên xuống
   int lineHeight = 18; // Khoảng cách giữa các dòng
   int fontSize = 10;
   color textColor = clrLime;
   
   // Tạo các label riêng biệt
   CreateLabel("Report_Title", "===== ACCOUNT REPORT =====" + AccountInfoInteger(ACCOUNT_LOGIN), 10, startY, fontSize, textColor);
   CreateLabel("Report_Line1", "minPriceBuyAmParam  : " + DoubleToString(minPriceBuyAmParam, 2), 10, startY + lineHeight, fontSize, textColor);
   CreateLabel("Report_Line2", "hightPriceSellAmParam  : " + DoubleToString(hightPriceSellAmParam, 2), 10, startY + lineHeight*2, fontSize, textColor);
   CreateLabel("Report_Line3", "lowPriceSellDuongParam : " + DoubleToString(lowPriceSellDuongParam, 2), 10, startY + lineHeight*3, fontSize, textColor);
   CreateLabel("Report_Line4", "hightPriceBuyDuongParam: " + DoubleToString(hightPriceBuyDuongParam, 2), 10, startY + lineHeight*4, fontSize, textColor);
   CreateLabel("Report_Sep", "--------------------------", 10, startY + lineHeight*6, fontSize, textColor);
   CreateLabel("Report_Bal", "Balance : " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), 10, startY + lineHeight*7, fontSize, textColor);
   CreateLabel("Report_Eq", "Equity  : " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), 10, startY + lineHeight*8, fontSize, textColor);
   ChartRedraw();
}

// Hàm tiện ích: thêm 1 phần tử vào mảng ulong
void AddToArray(ulong &arr[], ulong value)
{
   int size = ArraySize(arr);          // lấy kích thước hiện tại
   ArrayResize(arr, size + 1);         // tăng thêm 1 slot
   arr[size] = value;                  // gán giá trị mới vào cuối
}

// Hàm tính MA đơn giản từ Close Price
double MA_Custom(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod)
{
   double sum = 0;
   int count = 0;

   // Lấy giá đóng của 10 nến gần nhất (có thể lấy hơn)
   for(int i = 0; i < maPeriod; i++)
   {
      double closePrice = iClose(symbol, timeframe, i); // i = 0 là nến hiện tại
      if(closePrice == 0) break; // nếu lỗi, dừng
      sum += closePrice;
      count++;
   }

   if(count == 0) return 0;
   return sum / count;
}



// Hàm tạo label helper
void CreateLabel(string name, string text, int x, int y, int size, color clr)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
   }
   
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void ModifyPositionByTicket(ulong ticket, double newSL, double newTP)
{
    // Kiểm tra ticket tồn tại
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

    request.action   = TRADE_ACTION_SLTP; // Modify SL/TP
    request.position = ticket;            // Ticket cần modify
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

double CalculateRSI(int period ,  ENUM_TIMEFRAMES timeframe)
{
    double gain = 0;
    double loss = 0;
    // Get closing prices
    double closePrice[];
    int bars = CopyClose(_Symbol, timeframe, 0, period+1, closePrice);
    if(bars <= period) return 0; 
    // Calculate gains and losses
    for(int i=1; i<=period; i++)
    {
        double change = closePrice[i] - closePrice[i-1];
        if(change > 0) gain += change;
        else loss -= change; 
    }
    // Average gain and loss
    gain /= period;
    loss /= period;
    if(loss == 0) return 100; 
    double RS = gain / loss;
    double RSI = 100 - (100 / (1 + RS));
    return RSI;
}

double GetATRValue(int atr_period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
    // Tạo handle cho chỉ báo ATR
    int atr_handle = iATR(_Symbol, timeframe, atr_period);
    
    // Kiểm tra handle có hợp lệ không
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Không thể tạo handle cho ATR. Lỗi: ", GetLastError());
        return 0;
    }
    
    // Khai báo mảng để lấy dữ liệu ATR
    double atr_buffer[];
    
    // Sao chép dữ liệu ATR vào mảng
    int copied = CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
    
    // Kiểm tra xem dữ liệu có được sao chép thành công không
    if(copied <= 0)
    {
        Print("Không thể sao chép dữ liệu ATR. Lỗi: ", GetLastError());
        return 0;
    }
    // Giải phóng handle
    IndicatorRelease(atr_handle);
    // Trả về giá trị ATR
    return atr_buffer[0];
}

double checkProfit(int typePosition)
{
   double totalProfitBuy = 0;
   double totalProfitSell = 0;
   double totalProfit = 0;
   for(int i = 0 ; i <  PositionsTotal() ; i ++ ){
         ulong ticket = PositionGetTicket(i);
         int typePosition = PositionGetInteger(POSITION_TYPE);
         int positionMagic = PositionGetInteger(POSITION_MAGIC);
         double pricePosition = PositionGetDouble(POSITION_PRICE_OPEN);
         double volumn = PositionGetDouble(POSITION_VOLUME);
         string comment  = PositionGetString(POSITION_COMMENT);
         datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
         double profit = PositionGetDouble(POSITION_PROFIT);
        
         if(typePosition == POSITION_TYPE_BUY){
           
            totalProfitBuy = totalProfitBuy + profit;
            
         }else {
            
            totalProfitSell = totalProfitSell + profit;
         }
         totalProfit = totalProfit + profit;
     }
     if(typePosition == POSITION_TYPE_BUY)
     {
      return totalProfitBuy;
     }else if(typePosition == POSITION_TYPE_SELL)
     {
      return totalProfitSell;
     }else{
      return totalProfit;
     }
}

long lastUpdateId = 0;

bool checkOrderLimit(ENUM_TIMEFRAMES timefram , int limit){
  
   long timeLimit = 0;
   if(timefram == PERIOD_M1)
   {
      timeLimit =  60;
   }
   
   if(timefram == PERIOD_H1)
   {
      timeLimit =  60*60;
   }
   
   if(timefram == PERIOD_D1)
   {
      timeLimit = 60*60*24;
   }
   if(TimeCurrent() - timeCheckOrderLimit > timeLimit){
      timeCheckOrderLimit = TimeCurrent();
      countLimit = 0;
   }
   
   countLimit ++;
   if(countLimit > inputLimit)
   {
      return false;
   }
   return true;  
}

//+------------------------------------------------------------------+
//| Lấy tín hiệu Half Trend với thời gian chính xác                  |
//+------------------------------------------------------------------+
int GetHalfTrendSignal(datetime &signalTime, double &signalPrice)
{
   signalTime = 0;
   signalPrice = 0.0;
   if(halfTrendHandle == INVALID_HANDLE) 
      return 0;

   double upArrow[], downArrow[];
   datetime time[];
   ArraySetAsSeries(upArrow, true);
   ArraySetAsSeries(downArrow, true);
   ArraySetAsSeries(time, true);

   //--- Lấy dữ liệu mũi tên Buy (buffer 2), Sell (buffer 3) và thời gian
   if(CopyBuffer(halfTrendHandle, 2, 0, 3, upArrow) < 0 ||
      CopyBuffer(halfTrendHandle, 3, 0, 3, downArrow) < 0 ||
      CopyTime(Symbol(), Period(), 0, 3, time) < 0)
   {
      Print("Lỗi CopyBuffer/CopyTime: ", GetLastError());
      return 0;
   }

   //--- Kiểm tra tín hiệu ở nến trước (index 1)
   if(upArrow[1] != 0.0 && upArrow[1] != EMPTY_VALUE)
   {
      signalTime = time[1];
      signalPrice = upArrow[1];
      return 1; // UPTREND
   }
   else if(downArrow[1] != 0.0 && downArrow[1] != EMPTY_VALUE)
   {
      signalTime = time[1];
      signalPrice = downArrow[1];
      return -1; // DOWNTREND
   }

   return 0; 
}


void resetBot()
{
   if(AccountInfoDouble(ACCOUNT_EQUITY) >  priceCheckResetBot + price_for_reset)
   {
      priceCheckResetBot = AccountInfoDouble(ACCOUNT_EQUITY);
      CloseAllBuyPositions(magicNumberAm);
      CloseAllBuyPositions(magicNumberDuong);
      CloseAllSellPositions(magicNumberAm);
      CloseAllSellPositions(magicNumberDuong);
   }
}

// 📉 Hàm phát hiện thị trường sideway bằng ADX + Bollinger Band (chuẩn MQL5)
bool isSideway(ENUM_TIMEFRAMES period)
{
   // --- 1️⃣ Lấy giá trị ADX ---
   double adxLevel = 20.0;
   int adxPeriod = 14;
    int bbPeriod = 20; 
    double bbThreshold = 0.01;
   int adxHandle = iADX(_Symbol, period, adxPeriod);
   if(adxHandle == INVALID_HANDLE)
   {
      Print("❌ Không tạo được handle ADX");
      return false;
   }

   double adx[];
   if(CopyBuffer(adxHandle, 0, 0, 1, adx) <= 0)
   {
      Print("❌ Không lấy được dữ liệu ADX");
      return false;
   }
   double adxValue = adx[0];

   // --- 2️⃣ Lấy giá trị Bollinger Bands ---
   int bbHandle = iBands(_Symbol, PERIOD_H4, bbPeriod, 2.0, 0, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Print("❌ Không tạo được handle Bollinger Band");
      return false;
   }

   double upper[], lower[];
   if(CopyBuffer(bbHandle, 0, 0, 1, upper) <= 0 || CopyBuffer(bbHandle, 2, 0, 1, lower) <= 0)
   {
      Print("❌ Không lấy được dữ liệu Bollinger Band");
      return false;
   }

   // --- 3️⃣ Tính độ rộng Bollinger ---
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bandWidth = (upper[0] - lower[0]) / currentPrice;

   // --- 4️⃣ Kiểm tra điều kiện sideway ---
   bool adxWeak    = (adxValue < adxLevel);        // xu hướng yếu
   bool bandNarrow = (bandWidth < bbThreshold);    // biên độ hẹp

   if(adxWeak && bandNarrow)
   {
      PrintFormat("📉 Sideway detected | ADX=%.2f | BandWidth=%.2f%%", adxValue, bandWidth * 100);
      return true;
   }

   return false;
}



// --------------------------------------------------end common function---------------------------------------------------------------------------------------------------------------






