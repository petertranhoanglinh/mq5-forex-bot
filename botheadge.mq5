//+------------------------------------------------------------------+
//|                                                    botheadge.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include "utils.mqh"  
#include <Arrays\ArrayULong.mqh> // Include header cho CArrayULong 

input group "__Set Các chức năng DCA"; 
input double volumnSize = 0.01; // sỐ volumn vào lệnh
input double dcaBuySpacePrice   = 3;   // khoảng cách giá mỗi lệnh
input double tpBuyPrice = 3; // lợi nhuận mong muốn mỗi lệnh DCA BUY

input group "__Set Các chức năng liên quan tới Hedge";
input double maxLenhOpenHedge = 30;
input double priceDcaHedge = 1; // khoảng giá mua thêm hedge
input double valueDistance =  10; // khoảng giá thuận hedge để có thể đóng được lệnh xa nhất
input int divideHedge = 5; // Số lượng chia nhỏ lệnh cần hedge

input group "__Set Các chức năng liên quan tới Sell DCA";
input double maxOpenSell = 10;
input double dcaSellSpacePrice = 3;
input bool isDcaSell = true; // sử dụng dca sell
input double tpSellPrice = 3; //  lợi nhuận mong muốn mỗi lệnh DCA SELL
input double priceUpDcaSell = 0;// 
input double priceDownDcaSell = 0;//
input double volumnSell = 0.1; // lot cho lệnh SELL DCA


input group "__Set Bật chức năng sell theo trend";
input bool isSellTrend = true;
input double volumnTrend = 0.1; // lot cho lệnh SELL TREND

// biến liên quan tới lệnh dca
int countLenh = 0;
int countBuy = 0;
int countSell = 0;
double countProfitBuy = 0;
double countProfitSell = 0;
int magicNumber = 12345;


// biến liên quan tới lệnh hedge
int countHedge  = 0;
double priceOpenHedge = 0;
int magicHedge = 54321;
bool flagHedge =  false;
CArrayULong *ticketHedges;
double pricecheckClose = 0;



// chỉ báo 
int supertrendHandle;
int supertrendHandleM5;
int supertrendHandleM15;
int indi1 = 0 ; 
int indi2 = 0 ; 
int indi3 = 0 ; 
int resultIndi = 0 ; 

// biến liên quan tới sell trend
int magictrend = 555;
bool flagTrend = false;
double priceMaxTrend = 0;
double priceMinTrend = 0;




double artPriceSlHedge = 0;
double artPriceTPHedge = 0;
int setPriceHedgeGap = 0;
double atrValue = 0; 

//--- handle chỉ báo
int halfTrendHandle;
int    InpAmplitude   = 5;     // Amplitude
uchar  InpCodeUpArrow = 233;   // Arrow code for 'UpArrow' (Wingdings)
uchar  InpCodeDnArrow = 234;   // Arrow code for 'DnArrow' (Wingdings)
int    InpShift       = 10;    // Vertical shift of arrows

int OnInit()
  {
   TiaLenhSellDCA();
   ticketHedges = new CArrayULong(); // Thêm dòng này
   supertrendHandle = iCustom(_Symbol, PERIOD_M1, "Supertrend", 10, 3.0,PRICE_CLOSE,true,PERIOD_M1);
   supertrendHandleM5 = iCustom(_Symbol, PERIOD_M5, "Supertrend", 10, 3.0,PRICE_CLOSE,true,PERIOD_M5);
   supertrendHandleM15 = iCustom(_Symbol, PERIOD_M15, "Supertrend", 10, 3.0,PRICE_CLOSE,true,PERIOD_M15);
   
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
   if(supertrendHandle == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo handle cho chỉ báo Supertrend!");
      return(INIT_FAILED);
   }
    if(supertrendHandleM5 == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo handle  M5 ");
      return(INIT_FAILED);
   }
    if(supertrendHandleM15 == INVALID_HANDLE)
   {
      Print("Lỗi khi tạo handle   M15");
      return(INIT_FAILED);
   }    
   
   
   return(INIT_SUCCEEDED);
   
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ticketHedges != NULL) {
      delete ticketHedges;
      ticketHedges = NULL;
   }
}
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   filterTrend();
   TiaLenhSellDCA();
   atrValue= GetATRValue(14, PERIOD_H1); 
   datetime signalTime;// đánh giấu thới gian ghi nhận có tín hiệu 
   double signalPrice;
   int signal = GetHalfTrendSignal(signalTime, signalPrice);
   double profitHedge = 0;
   double volumnHedge = 0;
   
   double priceMinBuy = DBL_MAX;
   double priceMaxSell =DBL_MIN;
   double priceMinSell = DBL_MAX;
   double priceMaxHedgeSell = DBL_MIN;
   double priceMinHedgeSell = DBL_MAX;
   ulong ticketMaxHedge = 0;
   ulong ticketMinHedge = 0;
   static datetime lastSignalTime = 0;
   if(signal != 0 && signalTime > lastSignalTime)
   {
      lastSignalTime = signalTime;
      string text = (signal == 1) ? "UP" : "DOWN";
      color clr = (signal == 1) ? clrDeepSkyBlue : clrOrangeRed;
      DrawText(text + "_" + IntegerToString(TimeCurrent()), text, TimeCurrent(), signalPrice, clr);
      lastSignalTime = signalTime; // Luôn cập nhật sau khi vẽ
      if(signal == -1)
      {
       flagTrend = true;
       if(isSellTrend)
       {
         openSellTrend(volumnTrend);
       }
      }else{
       flagTrend = false;
      }
   }
   // xác định tín hiệu rõ ràng
   if(resultIndi == 1 && signal == 1)
   {
      signal = 1;
   } else if(resultIndi == -1 && signal == -1)
   {
      signal = -1;
   }else{
      signal = 0;
   }
   
   

   countBuy = 0;
   countSell = 0;
   countProfitBuy = 0;
   countProfitSell = 0;
   countLenh = 0;
   countHedge = 0;
   
   double priceLastedTrend = 0;
   datetime lastedtimeTrend = 0;
   
   for(int i = 0 ; i < PositionsTotal() ; i ++){
      ulong ticket = PositionGetTicket(i);  // ← LẤY TICKET TRƯỚC
      if(ticket > 0 && PositionSelectByTicket(ticket))  // ← SELECT TICKET
      {
         ulong typePosition = PositionGetInteger(POSITION_TYPE);
         ulong positionMagic = PositionGetInteger(POSITION_MAGIC);
         double profit = PositionGetDouble(POSITION_PROFIT);
         string positionSymbol = PositionGetString(POSITION_SYMBOL);
         double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double volumnCheck = PositionGetDouble(POSITION_VOLUME);
         datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(positionMagic == magicNumber && positionSymbol == _Symbol)
         {
            countLenh ++;
            if(typePosition == POSITION_TYPE_BUY)
            {
               countBuy++;
               countProfitBuy += profit;
               if(priceOpen < priceMinBuy)
               {
                  priceMinBuy = priceOpen;
               }
            }
            else if(typePosition == POSITION_TYPE_SELL)
            {
               countSell++;
               countProfitSell += profit;
               if( priceOpen > priceMaxSell)
               {
                  priceMaxSell = priceOpen;
               }
               
               if(priceOpen < priceMinSell)
               {
                  priceMinSell = priceOpen;
               }
            }
         }
         
         if(positionMagic == magicHedge && positionSymbol == _Symbol){
            countHedge ++;
            profitHedge += profit;
            volumnHedge += volumnCheck;
            if(ticketHedges != NULL) {
               ticketHedges.Add(ticket);
            }
            if(priceOpen > priceMaxHedgeSell)
            {
                priceMaxHedgeSell = priceOpen;
                ticketMaxHedge = ticket;
            }
            
            if(priceOpen < priceMinHedgeSell)
            {
                priceMinHedgeSell = priceOpen;
                ticketMinHedge = ticket;
            }
         }
         
         if(positionMagic == magictrend && positionSymbol == _Symbol)
         {
          
          if(priceOpen < priceMinTrend)
          {
            priceMinSell = priceOpen;
          }
          if(priceOpen > priceMaxTrend)
          {
            priceMaxTrend = priceOpen;
          }         
         }
      }
   }
   
  
   Print(countBuy);
   Print(priceMinBuy);
   Print(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if(countBuy == 0)
   {
       openBuyDca("lệnh BUY thứ: " + IntegerToString(countBuy) , volumnSize);
   }else
   {
       // dca âm cho buy
       double spaceBuy =  priceMinBuy - SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
       if(spaceBuy > dcaBuySpacePrice)
       {
          openBuyDca("lệnh BUY thứ: " + IntegerToString(countBuy) , volumnSize);
       }
   }
   
   if(isDcaSell)
   {
     if(countSell == 0 && signal == -1)
      {
          openSellDca("lệnh SELL thứ: " + IntegerToString(countSell) , volumnSell);
      }
      else if(countSell != 0 && signal == -1)
      {  
          // dca âm cho sell
          double spaceSell =  SymbolInfoDouble(_Symbol, SYMBOL_BID) - priceMaxSell;
          if(spaceSell > dcaSellSpacePrice)
          {
             openSellDca("lệnh SELL thứ: " + IntegerToString(countSell) , volumnSell);
          }
      }
   }
   // xác định giá mở hedge đầu tiên
   if(countHedge == 0  && countBuy >  maxLenhOpenHedge && signal == -1 )
   {
       int priceGap = (int(countBuy * dcaBuySpacePrice) + int(valueDistance))/int(valueDistance);
       if(priceGap > divideHedge)
       {
          priceGap = priceGap / divideHedge;
       }else{
         priceGap = 1;
       }
       setPriceHedgeGap = priceGap;
       double volumn = priceGap * volumnSize;
       if(volumn > 0)
       {
        openHedgeSell(volumn ,"Lệnh SELL HEDGE thứ: " + IntegerToString(countHedge));      
        priceOpenHedge = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       }
       flagHedge = true;
   }
   else if(countHedge > 0)
   {
         // mở thêm hedge nếu số lượng volumn hedge chưa đủ mở hedge theo chiều dương
         double spaceDcaSellHedge =    priceMinHedgeSell - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(countHedge < divideHedge && setPriceHedgeGap > 0 && spaceDcaSellHedge > priceDcaHedge)
         {
           double volumeH = volumnSize * double(setPriceHedgeGap);
           openHedgeSell(volumeH , "Lệnh SELL HEDGE thứ: " + IntegerToString(countHedge));
         }
         processHedgeClose(ticketMinHedge , ticketMaxHedge);
   }
}
  
void openBuyDca(string comment , double lot)
{
 openBuy(lot, 0 , tpBuyPrice ,magicNumber, comment);
}

void openSellDca(string comment , double lot)
{
 openSell(lot, 0 , tpSellPrice ,magicNumber, comment);
}

void openHedgeBuy(double volumnHedge)
{
    openBuy(volumnHedge, 0 , 0 ,magicHedge, "lệnh Hedge BUY");
}

bool openHedgeSell(double volumnHedge , string comment)
{
    return openSell(volumnHedge, 0 , tpBuyPrice ,magicHedge, comment);
}

bool openSellTrend(double volumn)
{
 return  openSell(volumn, atrValue/2 , atrValue/2  ,magictrend, "SELL_TREND");
}
int filterTrend(){
      double supertrendBuffer[];
      double supertrendBufferM5[];
      double supertrendBufferM15[];
      
      ArraySetAsSeries(supertrendBuffer, true);
      ArraySetAsSeries(supertrendBufferM5, true);
      ArraySetAsSeries(supertrendBufferM15, true);
      
      if(CopyBuffer(supertrendHandle, 0, 0, 2, supertrendBuffer) < 2)
      {
         Print("Lỗi sao chép dữ liệu Supertrend!");
         return 0; // Trả về 0 nếu có lỗi
      }
      
      if(CopyBuffer(supertrendHandleM5, 0, 0, 2, supertrendBufferM5) < 2)
      {
         Print("Lỗi sao chép dữ liệu M5");
         return 0; // Trả về 0 nếu có lỗi
      }
      
      if(CopyBuffer(supertrendHandleM15, 0, 0, 2, supertrendBufferM15) < 2)
      {
         Print("Lỗi sao chép dữ liệu M15");
         return 0; // Trả về 0 nếu có lỗi
      }
      
      double st_value = supertrendBuffer[1];
      double st_valueM5 = supertrendBufferM5[1];
      double st_valueM15 = supertrendBufferM15[1];
      
      MqlRates priceInfo[];
      ArraySetAsSeries(priceInfo, true);
      CopyRates(_Symbol, PERIOD_M1, 0, 2, priceInfo);
      double closePrice = priceInfo[1].close;
      
      MqlRates priceInfoM5[];
      ArraySetAsSeries(priceInfoM5, true);
      CopyRates(_Symbol, PERIOD_M5, 0, 2, priceInfoM5);
      double closePriceM5 = priceInfoM5[1].close;
      
      MqlRates priceInfoM15[];
      ArraySetAsSeries(priceInfoM15, true);
      CopyRates(_Symbol, PERIOD_M15, 0, 2, priceInfoM15);
      double closePriceM15 = priceInfoM15[1].close;
      
      indi1  = closePrice > st_value ? 1 : -1;
      indi2  = closePriceM5 > st_valueM5 ? 1 : -1;
      indi3  = closePriceM15 > st_valueM15 ? 1 : -1;
      
      if( indi1 != indi2 || indi1 != indi3 ){
         resultIndi = 0;
         return 0;
      }
      resultIndi = indi1;
      return indi1;
}

void processHedgeClose(ulong minticket , ulong maxticket)
{
   
   double minHedge =  0;
   if(PositionSelectByTicket(minticket) && minticket > 0)
   {
      minHedge = PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   double maxHedge =  0;
   if(PositionSelectByTicket(maxticket) && maxticket > 0)
   {
      maxHedge = PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   // close 1 phần lệnh hedge xa nhất nếu giá tiếp tục đi ngược lần đầu tiên
   if(flagHedge && SymbolInfoDouble(_Symbol, SYMBOL_BID) > minHedge + (atrValue * 0.5) )
   {
      ClosePartialPosition(minticket , volumnSize);
      pricecheckClose = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      flagHedge = false;
   }
   
   if(!flagHedge && SymbolInfoDouble(_Symbol, SYMBOL_BID) > pricecheckClose + (atrValue * 0.5) )
   {
      ClosePartialPosition(minticket , volumnSize);
      pricecheckClose = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   if(SymbolInfoDouble(_Symbol, SYMBOL_BID) < maxHedge - atrValue)
   {
      CloseAllSellPositions(magicHedge);
   }
   
}

//+------------------------------------------------------------------+
//| Hàm Tỉa Lệnh Sell DCA (ĐÃ SỬA)                                   |
//+------------------------------------------------------------------+
void TiaLenhSellDCA()
{
    int totalSell = 0;
    double totalProfit = 0;
    double maxLoss = 0;
    ulong lossTicket = 0;
    
    // Mảng lưu các lệnh có lời
    ulong profitTickets[];
    ArrayResize(profitTickets, 0);
    
    // Duyệt qua tất cả lệnh SELL
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        // Chỉ xét lệnh SELL của magic number chính
        if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL || 
           PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
        
        totalSell++;
        double profit = PositionGetDouble(POSITION_PROFIT);
        totalProfit += profit;
        
        // Lưu lệnh có lời
        if(profit > 0)
        {
            int size = ArraySize(profitTickets);
            ArrayResize(profitTickets, size + 1);
            profitTickets[size] = ticket;
        }
        // Tìm lệnh lỗ nhiều nhất
        else if(profit < maxLoss)
        {
            maxLoss = profit;
            lossTicket = ticket;
        }
    }
    
    // Điều kiện tỉa lệnh: Có ít nhất 1 lệnh lỗ và tổng lời > tổng lỗ
    if(lossTicket != 0 && totalProfit > 0)
    {
        // Đóng các lệnh có lời trước
        for(int i = 0; i < ArraySize(profitTickets); i++)
        {
            if(PositionSelectByTicket(profitTickets[i]))
            {
                trade.PositionClose(profitTickets[i]);
                Print("Đóng lệnh có lời: ", profitTickets[i]);
            }
        }
        // Đóng lệnh lỗ nhiều nhất
        if(PositionSelectByTicket(lossTicket))
        {
            trade.PositionClose(lossTicket);
            Print("Đóng lệnh lỗ: ", lossTicket, " | Lỗ: ", maxLoss);
        }
    }
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
