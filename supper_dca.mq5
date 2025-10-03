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
input group "__Set Các chức năng liên quan tới BUY DCA DƯƠNG"; 
input double lotBuyDuong = 0.01; // Số lot vào lệnh 
input double dcaPriceBuyDuong = 0.1; // khoảng giá DCA BUY DƯƠNG
input double tpBuyDcaDuong  = 0;
input bool  isDcaBuyDuong = true; // BẬT/ TẮT

input group "__Set Các chức năng liên quan tới SELL DCA DƯƠNG"; 
input double lotSellDuong = 0.01; // Số lot vào lệnh 
input double dcaPriceSellDuong = 0.1;// khoảng giá DCA SELL DƯƠNG
input double tpSellDcaDuong  = 0;
input bool  isDcaSellDuong = true; // BẬT/ TẮT

input group "_Dời SL TP DCA DƯƠNG NÂNG CAO"; 
input double checkProfitClose = 50; // Lợi nhuận tổng để đóng DCA DƯƠNG
input double new_tp_dca_duong = 3; // dời sl tp khi đổi trend
input double new_sl_dca_duong = 3; // dời sl tp khi đổi trend

input group "_Option chức năng giới hạn order limit";
input ENUM_TIMEFRAMES timeFrames = PERIOD_H1;// Khoảng thời gian giới hạn order
input double inputLimit = 200; // số lần giới hạn order
input double input_price_in_step = 10;
input int input_max_lenh_in_step = 30;

 
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
double avgPriceSell = 0;
double avgPriceBuy = 0;
int countHedgeBuy = 0;
int countHedgeSell = 0;
int OnInit()
  {
   countLimit = 0;
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
      if(isShutDownBotIsFail)
      {
        return;
      }
    }
    int totalPositonBUY = 0;
    int totalPositonSELL = 0;
    double profitBuyDuong = 0;
    double profitSellDuong = 0;
    double arrBuy [];
    double arrSell [];
    for(int i = 0 ; i <  PositionsTotal() ; i ++ ){
         ulong ticket = PositionGetTicket(i);
         int typePosition = PositionGetInteger(POSITION_TYPE);
         int positionMagic = PositionGetInteger(POSITION_MAGIC);
         double pricePosition = PositionGetDouble(POSITION_PRICE_OPEN);
         double volumn = PositionGetDouble(POSITION_VOLUME);
         string comment  = PositionGetString(POSITION_COMMENT);
         datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(magicNumberDuong == positionMagic)
         {
            if(typePosition == POSITION_TYPE_BUY){
            
               totalPositonBUY ++ ; 
               AddToArray(arrBuy , pricePosition);
               profitBuyDuong = profitBuyDuong + profit;
            }else {
               totalPositonSELL++ ; 
               AddToArray(arrSell , pricePosition);
               profitSellDuong = profitSellDuong + profit;
            }
         }
  }
  
  double hightPriceBuyDuong =  getPriceBuyDcaDuong(arrBuy);
  double lowPriceSellDuong = getPriceSellDcaDuong(arrSell);
  int trend = getTrendDirection(PERIOD_M1);
   if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - hightPriceBuyDuong >= dcaPriceBuyDuong && isDcaBuyDuong && isAcceptPrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) , arrBuy , dcaPriceBuyDuong) && trend == 1)
   {
       flagBotActive = openBuy(lotBuyDuong , 0 , 0 , magicNumberDuong , "BUY + | "  + IntegerToString(totalPositonBUY) + " | " + GetTimeVN());   
   }
   if(lowPriceSellDuong - SymbolInfoDouble(_Symbol, SYMBOL_BID) >=  dcaPriceSellDuong && isDcaSellDuong && isAcceptPrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) , arrSell , dcaPriceBuyDuong) && trend == -1)
   {
       flagBotActive = openSell(lotSellDuong, 0 , 0 , magicNumberDuong , "SELL + | "  + IntegerToString(totalPositonSELL) + " | " + GetTimeVN());
   }
   tradingStopSL();
   if(profitBuyDuong  + profitSellDuong > checkProfitClose)
   {
      flagBotActive = CloseAllBuyPositions(magicNumberDuong);
      flagBuy = false;
      flagBotActive = CloseAllSellPositions(magicNumberDuong);
      flagSell = false;
   }
}
// --------------------------------------------------logic bot function----------------------------------------------------------------------------------------------------------------
void calculator_Sl_Dca_Duong( int limit_tia_lenh){
   ulong arrWin[];
   ulong arrLost[];
   double profit = 0;
   bool haveSL = false;
   for(int i = 0 ; i < PositionsTotal() ; i++)
    {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        double sl = PositionGetDouble(POSITION_SL);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberDuong){        
               profit = profit + profitPostion;
               if(profitPostion > 25)
               {
                 AddToArray(arrWin, ticket);
               }
               if(profitPostion < -25){
                 AddToArray(arrLost, ticket);
                 if(sl != 0)
                 {
                  haveSL = true;
                 }
               }
            }
        }
    }
    for(int i = 0; i < ArraySize(arrWin); i++)
    {
      ulong ticket = arrWin[i];
      double currentPrice;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(PositionSelectByTicket(ticket)){
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volumn =  PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double newSl = 0;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newSl = openPrice + (MathAbs(openPrice - currentPrice)/2);
         }else{
            newSl =  openPrice - (MathAbs(openPrice - currentPrice)/2);
         }
         if(sl == 0 &&  newSl != 0)
         {
           ModifyPositionByTicket(ticket , newSl , 0);
         }
      }
    }
    
    int countSL =0 ;
    for(int i = 0; i < ArraySize(arrLost); i++)
    {
      ulong ticket = arrLost[i];
      double currentPrice;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(PositionSelectByTicket(ticket)){
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volumn =  PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double newSl = 0;
         double newTp = 0;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newSl = currentPrice - new_sl_dca_duong;
            newTp = currentPrice + new_tp_dca_duong;
         }else{
            newSl = currentPrice + new_sl_dca_duong;
            newTp = currentPrice +- new_tp_dca_duong;
         }
         if(sl == 0 &&  newSl != 0 && countSL < limit_tia_lenh && !haveSL)
         {
           ModifyPositionByTicket(ticket , newSl , newTp);
           countSL ++;
         }
      }
    }
}
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
   if(!checkOrderLimit(timeFrames , inputLimit))
   {
      Print("Limit Order Accept");
      return true;
   }
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
                    Print(" --------------------------------CLOSE BUY ORDER SUCCESS " + ticket + " | " + GetTimeVN() +" -----------------------------------------" );
                }
                else
                {
                    Print(" --------------------------------CLOSE BUY ORDER ERROR" + ticket + " | " + GetTimeVN() +" -----------------------------------------" );
                    result = false;
                }
            }
        }
    }
    Print(" --------------------------------CLOSE BUY ORDER SUCCESS COUNT " + totalClosed + " | " + GetTimeVN() +" -----------------------------------------" );
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
                     Print(" --------------------------------CLOSE SELL ORDER SUCCESS " + ticket + " | " + GetTimeVN() +" -----------------------------------------" );
                }
                else
                {
                     Print(" --------------------------------CLOSE SELL ORDER ERROR" + ticket + " |" + GetTimeVN() +" -----------------------------------------" );
                    result = false;
                }
            }
        }
    }
    Print(" --------------------------------CLOSE SELL ORDER SUCCESS COUNT " + totalClosed + " | " + GetTimeVN() +" -----------------------------------------" );
    return result;
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
// Hàm tiện ích: thêm 1 phần tử vào mảng ulong
void AddToArray(ulong &arr[], ulong value)
{
   int size = ArraySize(arr);          // lấy kích thước hiện tại
   ArrayResize(arr, size + 1);         // tăng thêm 1 slot
   arr[size] = value;                  // gán giá trị mới vào cuối
}

void AddToArray(double &arr[], double value)
{
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = value;
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
static bool flagBuy = false;
static bool flagSell = false;

double getPriceBuyDcaDuong(double &arr[])
{
  int size = ArraySize(arr);
  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  // chưa có lệnh nào
  if(size == 0)
  {
   return MA_Custom(_Symbol ,PERIOD_M5 , 14);
  }
  QuickSortAsc(arr , 0 , size - 1);

  int step = size / input_max_lenh_in_step;
  
  //
  if(arr[size-1] - currentPrice > 10 && !flagBuy)
  {
   flagBuy = true;
   return currentPrice - dcaPriceBuyDuong - 0.01;
  }
  
  if(flagBuy)
  {
   return FindNearestPrice(currentPrice , arr);
  }
  if(step == 0)
  {
   return arr[size-1];
  }
  
 
  if(size % input_max_lenh_in_step == 0)
  {
   return arr[size-1] + input_price_in_step;
  }
  
  return arr[size-1];
}
double getPriceSellDcaDuong(double &arr[])
{
  int size = ArraySize(arr);
  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  // chưa có lệnh nào
  if(size == 0)
  {
   return MA_Custom(_Symbol ,PERIOD_M5 , 14);
  }
  QuickSortAsc(arr , 0 , size - 1);
  int step = size / input_max_lenh_in_step;
  if(currentPrice - arr[0] > 10 && !flagSell)
  {
   flagSell = true;
   return currentPrice + dcaPriceSellDuong + 0.01;
  }
  if(flagSell)
  {
     return FindNearestPrice(currentPrice , arr);
  }
  if(step == 0)
  {
   return arr[0];
  }
  if(size % input_max_lenh_in_step == 0)
  {
   return arr[0] - input_price_in_step;
  }
  return arr[0];
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
//|                   QuickSort ASC (Tăng dần)                      |
//+------------------------------------------------------------------+
void QuickSortAsc(double &arr[], int left, int right)
{
   int i = left;
   int j = right;
   double pivot = arr[(left + right) / 2];
   

   while(i <= j)
   {
      while(arr[i] < pivot) i++;
      while(arr[j] > pivot) j--;

      if(i <= j)
      {
         double temp = arr[i];
         arr[i] = arr[j];
         arr[j] = temp;
         i++;
         j--;
      }
   }
   if(left < j)  QuickSortAsc(arr, left, j);
   if(i < right) QuickSortAsc(arr, i, right);
}

//+------------------------------------------------------------------+
//|                   QuickSort DESC (Giảm dần)                     |
//+------------------------------------------------------------------+
void QuickSortDesc(double &arr[], int left, int right)
{
   int i = left;
   int j = right;
   double pivot = arr[(left + right) / 2];

   while(i <= j)
   {
      while(arr[i] > pivot) i++;   // 👈 đảo dấu
      while(arr[j] < pivot) j--;   // 👈 đảo dấu

      if(i <= j)
      {
         double temp = arr[i];
         arr[i] = arr[j];
         arr[j] = temp;
         i++;
         j--;
      }
   }

   if(left < j)  QuickSortDesc(arr, left, j);
   if(i < right) QuickSortDesc(arr, i, right);
}

double floorTo(double value, double step)
{
   return MathFloor(value / step) * step;
}


bool isAcceptPrice(double price, double &arr[] , double step)
{
    price = floorTo(price , step);
   
    for(int i = 0; i < ArraySize(arr); i++)
    {
       if(price == floorTo(arr[i] , step)){
         return false;
       }
    }
    return true;
}


double FindNearestPrice(double currentPrice, const double &arr[])
{
   if (ArraySize(arr) == 0)
      return 0.0; // hoặc xử lý lỗi tuỳ bạn

   double nearest = arr[0];
   double minDiff = MathAbs(arr[0] - currentPrice);

   for (int i = 1; i < ArraySize(arr); i++)
   {
      double diff = MathAbs(arr[i] - currentPrice);
      if (diff < minDiff)
      {
         minDiff = diff;
         nearest = arr[i];
      }
   }
   return nearest;
}


int getTrendDirection(ENUM_TIMEFRAMES period)
{
   // --- 1️⃣ Lấy giá trị ADX & DI ---
   double adxLevel = 20.0;
   int adxPeriod = 14;
   int bbPeriod = 20; 
   double bbThreshold = 0.01;

   int adxHandle = iADX(_Symbol, period, adxPeriod);
   if(adxHandle == INVALID_HANDLE)
   {
      Print("❌ Không tạo được handle ADX");
      return 0;
   }

   double adx[], plusDI[], minusDI[];
   if(CopyBuffer(adxHandle, 0, 0, 1, adx) <= 0 || 
      CopyBuffer(adxHandle, 1, 0, 1, plusDI) <= 0 || 
      CopyBuffer(adxHandle, 2, 0, 1, minusDI) <= 0)
   {
      Print("❌ Không lấy được dữ liệu ADX/DI");
      return 0;
   }

   double adxValue   = adx[0];
   double plusDIVal  = plusDI[0];
   double minusDIVal = minusDI[0];

   // --- 2️⃣ Lấy giá trị Bollinger Bands ---
   int bbHandle = iBands(_Symbol, period, bbPeriod, 2.0, 0, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Print("❌ Không tạo được handle Bollinger Band");
      return 0;
   }

   double upper[], lower[];
   if(CopyBuffer(bbHandle, 0, 0, 1, upper) <= 0 || 
      CopyBuffer(bbHandle, 2, 0, 1, lower) <= 0)
   {
      Print("❌ Không lấy được dữ liệu Bollinger Band");
      return 0;
   }

   // --- 3️⃣ Tính độ rộng Bollinger ---
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double bandWidth = (upper[0] - lower[0]) / currentPrice;

   // --- 4️⃣ Kiểm tra điều kiện sideway ---
   bool adxWeak    = (adxValue < adxLevel);        
   bool bandNarrow = (bandWidth < bbThreshold);    

   if(adxWeak && bandNarrow)
   {
      PrintFormat("📉 Sideway detected | ADX=%.2f | BandWidth=%.2f%%", adxValue, bandWidth * 100);
      return 0;
   }

   // --- 5️⃣ Xác định xu hướng ---
   if(plusDIVal > minusDIVal)
   {
      PrintFormat("📈 Uptrend detected | ADX=%.2f | +DI=%.2f > -DI=%.2f", adxValue, plusDIVal, minusDIVal);
      return 1;
   }
   else if(minusDIVal > plusDIVal)
   {
      PrintFormat("📉 Downtrend detected | ADX=%.2f | -DI=%.2f > +DI=%.2f", adxValue, minusDIVal, plusDIVal);
      return -1;
   }

   // fallback nếu không rõ
   return 0;
}

void tradingStopSL()
{
   ulong arrWin[];
   double profit = 0;
   for(int i = 0 ; i < PositionsTotal() ; i++)
    {
        ulong ticket = PositionGetTicket(i);
        double profitPostion = PositionGetDouble(POSITION_PROFIT);
        double sl = PositionGetDouble(POSITION_SL);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumberDuong){        
               profit = profit + profitPostion;
               if(profitPostion > 30)
               {
                 AddToArray(arrWin, ticket);
               }
            }
        }
    }
    for(int i = 0; i < ArraySize(arrWin); i++)
    {
      ulong ticket = arrWin[i];
      double currentPrice;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
          currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(PositionSelectByTicket(ticket)){
         double profit = PositionGetDouble(POSITION_PROFIT);
         double volumn =  PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double newSl = 0;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newSl = openPrice + (MathAbs(openPrice - currentPrice)/2);
         }else{
            newSl =  openPrice - (MathAbs(openPrice - currentPrice)/2);
         }
         if(sl == 0 &&  newSl != 0)
         {
           ModifyPositionByTicket(ticket , newSl , 0);
         }
      }
    }

}
// --------------------------------------------------end common function---------------------------------------------------------------------------------------------------------------
