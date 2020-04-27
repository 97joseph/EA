//+------------------------------------------------------------------+
//|                                                                  |
//|   Research on the best indicators
//|                        
//|                                                                  |
//|                                                                                     
//|                                                                  |
//+------------------- SIMLPLE ATR --------------------+

   /* 
      ENTRY RULES:
      Enter a long trade when Monday is a up day and it's price change is greater than ATR(14) on Daily Timeframe
      Enter a short trade when Monday is a down day and it's price change is greater than ATR(14) on Daily Timeframe
   
       EXIT RULES:
      1*ATR(14) (on Daily Timeframe) Stop Loss
      2*ATR(14) (on Daily Timeframe) Take Profit 
         
       POSITION SIZING RULE:
      Sizing based on account size
   */

#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

// TDL 4: Declare required Extern Variables and Variables

extern int MagicNumber = 12345;
extern bool SignalMail = False;
extern int Slippage = 3;
extern bool UseStopLoss = True;
extern int StopLoss = 30;
extern bool isVolatilityStopOn = True; 
extern int VolBasedSLMultipler = 1;
extern bool UseTakeProfit = True;
extern int TakeProfit = 0;
extern bool isVolatilityTakeProfitOn = True; 
extern int VolBasedTPMultipler = 2;
extern bool UseTrailingStop = False;
extern int TrailingStop = 0;

extern int entryRuleVersion = 1;
extern int atr_period = 14;
extern int ATRmultiplier = 1;

extern double Lots = 1.0;
extern bool isSizingOn = true;
extern double Risk = 3;

int P = 1;
int Order = SIGNAL_NONE;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;
double YenPairAdjustFactor = 1;

int current_direction, last_direction;
bool first_time = True;
double StopLossFinal, TakeProfitFinal, LotsFinal, ATR;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   
   if(Digits == 5 || Digits == 3 || Digits == 1)P = 10;else P = 1; // To account for 5 digit brokers
   if(Digits == 3 || Digits == 2) YenPairAdjustFactor = 100; // Adjust for YenPair

   return(0);
}
//+------------------------------------------------------------------+
//| Expert initialization function - END                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   return(0);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function - END                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert start function                                            |
//+------------------------------------------------------------------+
int start() {

   Total = OrdersTotal();
   Order = SIGNAL_NONE;

   //+------------------------------------------------------------------+
   //| Variable Setup                                                   |
   //+------------------------------------------------------------------+
   
   // TDL 1: Create a 2 functions to calculate volatilty Stop Loss and Take Profit (in pips) respectively
   // Then assign them to StopLoss and TakeProfit
   
   ATR = iATR(NULL,PERIOD_D1,atr_period,0);
   
   StopLossFinal = volBasedStopLoss(isVolatilityStopOn, StopLoss, ATR, VolBasedSLMultipler, P);
   // volBasedStopLoss(bool isVolatilitySwitchOn, double fixedStop, double volATR, double volMultiplier, int K)
   TakeProfitFinal = volBasedTakeProfit(isVolatilityTakeProfitOn, TakeProfit, ATR, VolBasedTPMultipler, P);
   // volBasedTakeProfit(bool isVolatilitySwitchOn, double fixedTP, double volATR, double volMultiplier, int K)
   
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD)) / P; // Defining minimum StopLevel

   if (StopLossFinal < StopLevel) StopLossFinal = StopLevel;
   if (TakeProfitFinal < StopLevel) TakeProfitFinal = StopLevel;
   
   // TDL 2: Create a function to calculate position size
   
   LotsFinal = getLot(isSizingOn, Lots, Risk, YenPairAdjustFactor, StopLossFinal, P); 
   // getLot(bool isSizingOnTrigger, ,double fixedLots, double riskPerTrade, int yenAdjustment, double stops, int K)

   //+------------------------------------------------------------------+
   //| Variable Setup - END                                             |
   //+------------------------------------------------------------------+

   //Check position
   bool IsTrade = False;

   for (int i = 0; i < Total; i ++) {
      Ticket2 = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = True;
         if(OrderType() == OP_BUY) {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            /*  
                EXIT RULES:
               1*ATR(14) (on Daily Timeframe) Stop Loss
               2*ATR(14) (on Daily Timeframe) Take Profit 
               
               We don't have to input the exit rules here. The exit rules are incorporated in our Hard Stop Loss
            */
            
            
            //if() Order = SIGNAL_CLOSEBUY; // Rule to EXIT a Long trade

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSEBUY) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               IsTrade = False;
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if(Bid - OrderOpenPrice() > P * Point * TrailingStop) {
                  if(OrderStopLoss() < Bid - P * Point * TrailingStop) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Bid - P * Point * TrailingStop, OrderTakeProfit(), 0, MediumSeaGreen);
                     continue;
                  }
               }
            }
         } else {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+

           //if () Order = SIGNAL_CLOSESELL; // Rule to EXIT a Short trade

            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSESELL) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if((OrderOpenPrice() - Ask) > (P * Point * TrailingStop)) {
                  if((OrderStopLoss() > (Ask + P * Point * TrailingStop)) || (OrderStopLoss() == 0)) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Ask + P * Point * TrailingStop, OrderTakeProfit(), 0, DarkOrange);
                     continue;
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Signal Begin(Entries)                                            |
   //+------------------------------------------------------------------+

   /* 
      ENTRY RULES:
      Enter a long trade when Monday is a up day and it's price change is greater than ATR(14) on Daily Timeframe
      Enter a short trade when Monday is a down day and it's price change is greater than ATR(14) on Daily Timeframe
  
   */
   
   // TDL 3: Create Entry rules using a function
   
      if (entryRules(entryRuleVersion, ATRmultiplier, ATR) == 1) Order = SIGNAL_BUY; // Rule to ENTER a Long trade
      // entryRules(double ATR_K, double volATR)
         
      if (entryRules(entryRuleVersion, ATRmultiplier, ATR) == -1) Order = SIGNAL_SELL; // Rule to ENTER a Short trade

   
   //+------------------------------------------------------------------+
   //| Signal End                                                       |
   //+------------------------------------------------------------------+

   //Buy
   if (Order == SIGNAL_BUY) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Ask - StopLossFinal * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfitFinal * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_BUY, LotsFinal, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("BUY order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Open Buy");
			} else {
				Print("Error opening BUY order : ", GetLastError());
			}
         }
         return(0);
      }
   }

   //Sell
   if (Order == SIGNAL_SELL) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            noMoneyPrint();
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Bid + StopLossFinal * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfitFinal * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_SELL, LotsFinal, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("SELL order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Open Sell");
			} else {
				Print("Error opening SELL order : ", GetLastError());
			}
         }
         return(0);
      }
   }

   return(0);
}


//+------------------------------------------------------------------+

//+------------------------------------------------------------------------------------------------------------------------------------+
// FUNCTIONS LIBRARY                                                                                                                   
//+------------------------------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
// Customized Print                                                  
//+------------------------------------------------------------------+
void noMoneyPrint(){

   Print("We have no money. Free Margin = ", AccountFreeMargin());

}
//+------------------------------------------------------------------+
// End of Customized Print                                           
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
// Cross                                                             
//+------------------------------------------------------------------+

// We didn't use the Cross function for  but it is a good habit to keep the functions here for potential future use

/* 

Function Notes:

Declare these before the init() of the EA 

int current_direction, last_direction;
bool first_time = True;

----  

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed(double line1 , double line2) 
  {

//----
    if(line1 > line2)
        current_direction = 1;  // line1 above line2
    if(line1 < line2)
        current_direction = 2;  // line1 below line2
//----
    if(first_time == true) // Need to check if this is the first time the function is run
      {
        first_time = false; // Change variable to false
        last_direction = current_direction; // Set new direction
        return (0);
      }

    if(current_direction != last_direction && first_time == false)  // If not the first time and there is a direction change
      {
        last_direction = current_direction; // Set new direction
        return(current_direction); // 1 for up, 2 for down
      }
    else
      {
        return (0);  // No direction change
      }
  }


//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility Stop Loss                                             
//+------------------------------------------------------------------+

// TDL 1: 

double volBasedStopLoss(bool isVolatilitySwitchOn, double fixedStop, double volATR, double volMultiplier, int K) // K represents our P multiplier to adjust for broker digits
  {
  
  double StopL;
  
      if(!isVolatilitySwitchOn){
         StopL=fixedStop; // If Volatility Stop Loss not activated. Stop Loss = Fixed Pips Stop Loss
      } else {
         StopL=volMultiplier*volATR/(K*Point); // Stop Loss in Pips
      }
      
  return(StopL);
  
  }

//+------------------------------------------------------------------+
//| End of Volatility Stop Loss // CURRENT SYMBOL                    
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Take Profit                                     
//+------------------------------------------------------------------+

// TDL 1: 

double volBasedTakeProfit(bool isVolatilitySwitchOn, double fixedTP, double volATR, double volMultiplier, int K) // K represents our P multiplier to adjust for broker digits
  {
  
  double TakeP;
  
      if(!isVolatilitySwitchOn){
         TakeP=fixedTP; // If Volatility Take Profit not activated. Take Profit = Fixed Pips Take Profit
      } else {
         TakeP=volMultiplier*volATR/(K*Point); // Take Profit in Pips
      }
    
  return(TakeP);
  
  }

//+------------------------------------------------------------------+
//| End of Volatility-Based Take Profit                 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Position Sizing Algo               
//+------------------------------------------------------------------+
   
// TDL 2: 
   
double getLot(bool isSizingOnTrigger,double fixedLots, double riskPerTrade, int yenAdjustment, double stops, int K) {
   
   double output;
      
   if (isSizingOnTrigger == true) {
      output = riskPerTrade * 0.01 * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * stops * K * Point); // Sizing Algo based on account size
      output = output * yenAdjustment; // Adjust for Yen Pairs
   } else {
      output = fixedLots;
   }
   output = NormalizeDouble(output, 2); // Round to 2 decimal place
   return(output);
}
   
//+------------------------------------------------------------------+
//| End of Position Sizing Algo               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Entry Rule                                                        
//+------------------------------------------------------------------+

// TDL 3: 

int entryRules(int ver, double ATR_K, double volATR) {
   
   double mondayPriceChangeUpDay = 0;
   double mondayPriceChangeDownDay = 0;
   double mondayPriceChange = 0;
   int output = 0;
   
   if(DayOfWeek() == 2) if(Hour() == 0){

      if (ver == 1) {
         mondayPriceChange = iClose(NULL,PERIOD_D1,1) - iOpen(NULL,PERIOD_D1,1);
         if (mondayPriceChange > 0) mondayPriceChangeUpDay = mondayPriceChange;
         if (mondayPriceChange < 0) mondayPriceChangeDownDay = MathAbs(mondayPriceChange);
      }
    
      if (ver == 2) {
         mondayPriceChangeUpDay = iHigh(NULL,PERIOD_D1,1) - iOpen(NULL,PERIOD_D1,1);
         mondayPriceChangeDownDay = iOpen(NULL,PERIOD_D1,1) - iLow(NULL,PERIOD_D1,1);
      }
      
      if (mondayPriceChangeUpDay > ATR_K * volATR){
         output = 1; // Long signal
      } else if (mondayPriceChangeDownDay > ATR_K * volATR){
         output = -1; // Short signal
      }
      
   }
   
   return(output);
}
//+------------------------------------------------------------------+
// End of Entry Rule                                                 
//+------------------------------------------------------------------+