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
input double dcaPriceBuyDuong = 1; // khoảng giá DCA BUY DƯƠNG
input double tpBuyDcaDuong  = 0;
input bool  isDcaBuyDuong = true; // BẬT/ TẮT

input group "__Set Các chức năng liên quan tới SELL DCA DƯƠNG"; 
input double lotSellDuong = 0.03; // Số lot vào lệnh 
input double dcaPriceSellDuong = 1;// khoảng giá DCA SELL DƯƠNG
input double tpSellDcaDuong  = 0;
input bool  isDcaSellDuong = true; // BẬT/ TẮT

input group "_Dời SL TP DCA DƯƠNG NÂNG CAO"; 
input double tp_sl_dca_duong = 50; // lợi nhuận nếu tổng DCA dương đạt tới sẽ dời SL
input double checkProfitClose = 100; // Lợi nhuận tổng để đóng DCA DƯƠNG

input group "_Hedge Nâng Cao nếu tài khoản âm quá nhiều"; 

input double profitLostPram = -100; // set lệnh nếu profit nhỏ hơn sẽ dời sl theo tín hiệu rsi
input double new_tp_dca_am = 30;
input double new_sl_dca_am = 30;
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



datetime timelastedSendTelegram = 0;
datetime time_check_sp_tp_dca_am = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
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
     if(!IsMarketOpen(Symbol()))
    {
        Print("MARKET CLOSE BOT SHUTDOWN, " , GetTimeVN());
        return;
    }
    checkDrawDown();
    calculator_Sl_Dca_Duong();
    if((TimeCurrent() - time_check_sp_tp_dca_am) >= 60*5)
    {
         time_check_sp_tp_dca_am = TimeCurrent();
         calculator_Sl_Dca_Am();
    }
    double minPriceBuy = DBL_MAX;
    double hightPriceBuyDuong =  0;
    double lowPriceSellDuong = DBL_MAX;
    double hightPriceSELL = 0;
    int totalPositonBUY = 0;
    int totalPositonSELL = 0;
    double profitBuyDuong = 0;
    double profitSellDuong = 0;
    // avairable âm
    double minPriceBuyAm = DBL_MAX;
    double hightPriceSellAm = 0;
    int totalPositonAmBUY = 0;
    int totalPositonAmSELL = 0;
    for(int i = 0 ; i <  PositionsTotal() ; i ++ ){
         ulong ticket = PositionGetTicket(i);
         int typePosition = PositionGetInteger(POSITION_TYPE);
         int positionMagic = PositionGetInteger(POSITION_MAGIC);
         double pricePosition = PositionGetDouble(POSITION_PRICE_OPEN);
         double volumn = PositionGetDouble(POSITION_VOLUME);
         datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(magicNumberDuong == positionMagic)
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
     string report = ReportAccount(minPriceBuyAm , hightPriceSellAm , lowPriceSellDuong , hightPriceBuyDuong);
     ShowReport(minPriceBuyAm , hightPriceSellAm , lowPriceSellDuong , hightPriceBuyDuong);
     if((TimeCurrent() - timelastedSendTelegram) >= 60*15)
       {
            timelastedSendTelegram = TimeCurrent();
            SendTelegramMessage(report);
            
       }
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
         if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - hightPriceBuyDuong > dcaPriceBuyDuong && isDcaBuyDuong && totalPositonSELL == 0)
         {
             flagBotActive = openBuy(lotBuyDuong , 0 , 0 , magicNumberDuong , "BUY +| "  + IntegerToString(totalPositonBUY) + " AT: " + GetTimeVN());   
         }
         if(lowPriceSellDuong - SymbolInfoDouble(_Symbol, SYMBOL_BID) >  dcaPriceSellDuong && isDcaSellDuong && totalPositonBUY == 0){
             flagBotActive = openSell(lotSellDuong, 0 , 0 , magicNumberDuong , "SELL +| "  + IntegerToString(totalPositonSELL) + " AT: " + GetTimeVN());
         }
         
         if(profitBuyDuong + profitSellDuong > checkProfitClose)
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
         if(minPriceBuyAm - SymbolInfoDouble(_Symbol, SYMBOL_ASK) >  dcaBuyPriceAm && isDcaBuyAm )
         {
           flagBotActive = openBuy(lotBuyAm , 0 , tpBuyAm , magicNumberAm , "BUY -|  "  + IntegerToString(totalPositonAmBUY) + " AT: " + GetTimeVN()); 
         }
         
         if(SymbolInfoDouble(_Symbol, SYMBOL_BID) - hightPriceSellAm > dcaSellPriceAm && isDcaSellAm)
         {
           flagBotActive = openSell(lotSellAm , 0 , tpSellAm , magicNumberAm , "SELL -|  "  + IntegerToString(totalPositonAmSELL) + " AT: " + GetTimeVN());
         }
     }
}


// --------------------------------------------------logic bot function----------------------------------------------------------------------------------------------------------------

void calculator_Sl_Dca_Duong(){
   ulong arrWin[];
   int positonType  ;
   double profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberDuong){        
               profit = profit + profitPostion;
               positonType = PositionGetInteger(POSITION_TYPE);
               if(profit > 0)
               {
                  AddToArray(arrWin, ticket);
               }
            }
           
        }
    }
    // 
    if(profit > tp_sl_dca_duong)
    {
       // update sl
       for(int i = 0; i < ArraySize(arrWin); i++)
       {
         ulong ticket = arrWin[i];
         Print("TICKET CẦN SL LÀ: ", ticket);
         double currentPrice;
         if(positonType == POSITION_TYPE_BUY)
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         else
             currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(PositionSelectByTicket(ticket)){
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volumn =  PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double newSl = 0;
            if(positonType == POSITION_TYPE_BUY)
            {
               newSl = openPrice  +  ((currentPrice - openPrice) / 2);
            }else{
               newSl = openPrice  - ((openPrice - currentPrice) / 2);
            }
             if(sl == 0)
            {
              ModifyPositionByTicket(ticket , newSl , 0);
            }
           
         }
         
       }
    }

}

void calculator_Sl_Dca_Am(){
   ulong arrLost[];
   double profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberAm){        
               profit = profit + profitPostion;
               if(profit < profitLostPram)
               {
                  AddToArray(arrLost, ticket);
               }
            }
        }
    }
    double rsi = CalculateRSI(14 ,  PERIOD_H1);
    int type = 0;
    
    if(rsi < 30){
      type = 1; // giá có xu hướng tăng
    }
    if(rsi > 70)
    {
     type = -1; // giá có xu hướng giảm
    }
    
    if(type == 1)
    {
       for(int i = 0; i < ArraySize(arrLost); i++)
       {
         ulong ticket = arrLost[i];
         Print("TICKET CẦN SL LÀ: ", ticket);
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
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               newSl = currentPrice - (new_sl_dca_am / distanceIn1Price);
               newTp = currentPrice + (new_tp_dca_am / distanceIn1Price);
            }else{
               newSl = currentPrice + (new_sl_dca_am / distanceIn1Price);
               newTp = currentPrice - (new_tp_dca_am / distanceIn1Price);
            }
            if(sl == 0)
            {
              ModifyPositionByTicket(ticket , newSl , newTp);
            }
           
         }
         
       }
    }
    
    
     
    
}
// --------------------------------------------------end logic bot function----------------------------------------------------------------------------------------------------------------


// --------------------------------------------------common function---------------------------------------------------------------------------------------------------------------

bool openBuy(double volumn, double stoploss, double takeProfit, int magic , string comment)
{
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

bool IsMarketOpen(string symbol)
{
    // Kiểm tra symbol có tồn tại không
    if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
        return false;
    // Kiểm tra chế độ giao dịch
    long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    if(trade_mode != SYMBOL_TRADE_MODE_FULL)
        return false;
    // Kiểm tra thời gian hiện tại
    datetime current_time = TimeCurrent();
    MqlDateTime mql_time;
    TimeToStruct(current_time, mql_time);
    // Kiểm tra các session giao dịch trong ngày
    datetime session_start, session_end;
    int session_index = 0;
    
    while(SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)mql_time.day_of_week, session_index, session_start, session_end))
    {
        // Chuyển session time về cùng ngày với current_time
        MqlDateTime start_struct, end_struct;
        TimeToStruct(session_start, start_struct);
        TimeToStruct(session_end, end_struct);
        
        start_struct.year = mql_time.year;
        start_struct.mon = mql_time.mon;
        start_struct.day = mql_time.day;
        
        end_struct.year = mql_time.year;
        end_struct.mon = mql_time.mon;
        end_struct.day = mql_time.day;
        
        datetime today_start = StructToTime(start_struct);
        datetime today_end = StructToTime(end_struct);
        
        if(today_end < today_start)
            today_end += 86400; // Thêm 1 ngày
        
        if(current_time >= today_start && current_time < today_end)
            return true;
        
        session_index++;
    }
    return false;
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

string ReportAccount(double minPriceBuyAmParam , double hightPriceSellAmParam , double lowPriceSellDuongParam , double hightPriceBuyDuongParam)
{
   string accountInfo = "";
   accountInfo += "===== 📊 ACCOUNT REPORT: "+AccountInfoInteger(ACCOUNT_LOGIN)+" "+AccountInfoString(ACCOUNT_NAME)+"=====\n" ;
   accountInfo += "===== INFO DCA AM =====\n";
   accountInfo += "minPriceBuyAmParam: "   + DoubleToString(minPriceBuyAmParam, 2) + "\n";
   accountInfo += "hightPriceSellAmParam: "   + DoubleToString(hightPriceSellAmParam, 2) + "\n";
   accountInfo += "===== INFO DCA DƯƠNG =====\n";
   accountInfo += "lowPriceSellDuongParam: "   + DoubleToString(lowPriceSellDuongParam, 2) + "\n";
   accountInfo += "hightPriceBuyDuongParam: "   + DoubleToString(hightPriceBuyDuongParam, 2) + "\n";
   accountInfo += "Balance : "   + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   accountInfo += "Equity  : "   + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   return accountInfo;
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

// --------------------------------------------------end common function---------------------------------------------------------------------------------------------------------------

