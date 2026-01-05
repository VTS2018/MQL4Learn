//+------------------------------------------------------------------+
//|                                     03-ZigZag指标模块.mqh       |
//|                        各种ZigZag算法实现和数据处理模块          |
//|                     模块化设计 - 专业的ZigZag技术分析支持         |
//+------------------------------------------------------------------+

#property copyright "谐波形态指标ZigZag模块"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| 模块说明                                                          |
//+------------------------------------------------------------------+
/*
本模块包含所有ZigZag指标相关的算法和函数：
1. 经典ZigZag算法实现
2. 增强版ZigZag算法（Tauber、SQZZ等）
3. 多种NoGorb算法
4. ZigZag数据处理和访问
5. 分形计算和峰值标注
6. 角度分析和Ensign ZZ
7. Gann Swing分析
8. VTS相关ZigZag处理
*/

//+------------------------------------------------------------------+
//| 经典ZigZag算法                                                    |
//+------------------------------------------------------------------+

// 主要ZigZag算法
void ZigZag_()
{
   // 经典ZigZag算法实现
   int i, counted_bars = IndicatorCounted();
   double curLow, curHigh, lastHigh, lastLow;
   
   if(Bars < ExtDepth) return;
   
   // ZigZag计算逻辑
   for(i = Bars - ExtDepth; i >= 0; i--)
   {
      curLow = Low[Lowest(MODE_LOW, ExtDepth, i)];
      curHigh = High[Highest(MODE_HIGH, ExtDepth, i)];
      
      // ZigZag点识别和存储
      if(curLow == Low[i])
      {
         zzL[i] = curLow;
      }
      else
      {
         zzL[i] = 0;
      }
      
      if(curHigh == High[i])
      {
         zzH[i] = curHigh;
      }
      else
      {
         zzH[i] = 0;
      }
      
      // 合并ZigZag数据
      if(zzL[i] != 0 && zzH[i] != 0)
      {
         if(zzL[i] < zzH[i])
            zzH[i] = 0;
         else
            zzL[i] = 0;
      }
      
      zz[i] = (zzL[i] != 0) ? zzL[i] : zzH[i];
   }
}

// NoGorb新版算法
void NoGorb_New(int Depth)
{
   // 新版NoGorb算法，更精确的峰值识别
   for(int i = Bars - Depth - 1; i >= Depth; i--)
   {
      double val = 0;
      
      // 查找局部最高点
      if(High[i] == High[ArrayMaximum(High, Depth*2+1, i-Depth)])
      {
         val = High[i];
      }
      
      // 查找局部最低点
      if(Low[i] == Low[ArrayMinimum(Low, Depth*2+1, i-Depth)])
      {
         if(val > 0)
         {
            // 如果同时是高点和低点，选择更显著的
            if(MathAbs(High[i] - Low[i-1]) > MathAbs(Low[i] - High[i-1]))
               val = High[i];
            else
               val = Low[i];
         }
         else
         {
            val = Low[i];
         }
      }
      
      zz[i] = val;
   }
}

// NoGorb经典算法
void NoGorb(int Depth)
{
   // 经典NoGorb算法
   for(int i = Bars - Depth; i >= 0; i--)
   {
      double val = 0;
      
      if(High[i] == High[ArrayMaximum(High, Depth, i)])
         val = High[i];
      
      if(Low[i] == Low[ArrayMinimum(Low, Depth, i)])
      {
         if(val == 0)
            val = Low[i];
         else
         {
            // 冲突解决
            val = (MathAbs(High[i] - Close[i]) < MathAbs(Low[i] - Close[i])) ? High[i] : Low[i];
         }
      }
      
      zz[i] = val;
   }
}

//+------------------------------------------------------------------+
//| 高级ZigZag算法                                                    |
//+------------------------------------------------------------------+

/**
 * Tauber ZigZag算法 - 完整版本
 * 功能：递归分析的高精度ZigZag算法
 * 复杂度：约110行算法逻辑  
 * 特点：使用递归最高/最低点查找，具有高精度转折点识别
 */
void ZigZag_tauber()
{
   int    shift, back,lasthighpos,lastlowpos;
   double val,res;
   double curlow,curhigh,lasthigh,lastlow;

   int    metka=0;
   double peak, wrpeak;

   ArrayInitialize(zz,0.0);
   ArrayInitialize(zzL,0.0);
   ArrayInitialize(zzH,0.0);
   if (ExtLabel>0)
   {
      ArrayInitialize(la,0.0);
      ArrayInitialize(ha,0.0);
   }

   GetHigh(0,Bars,0.0,0);

   lasthigh=-1; lasthighpos=-1;
   lastlow=-1;  lastlowpos=-1;

   for(shift=Bars; shift>=0; shift--)
   {
      curlow=zzL[shift];
      curhigh=zzH[shift];
      if((curlow==0)&&(curhigh==0)) continue;

      if(curhigh!=0)
      {
         if(lasthigh>0) 
         {
            if(lasthigh<curhigh) zzH[lasthighpos]=0;
            else zzH[shift]=0;
         }

         if(lasthigh<curhigh || lasthigh<0)
         {
            lasthigh=curhigh;
            lasthighpos=shift;
         }
         lastlow=-1;
      }

      if(curlow!=0)
      {
         if(lastlow>0)
         {
            if(lastlow>curlow) zzL[lastlowpos]=0;
            else zzL[shift]=0;
         }

         if((curlow<lastlow)||(lastlow<0))
         {
            lastlow=curlow;
            lastlowpos=shift;
         } 
         lasthigh=-1;
      }
   }

   for(shift=Bars-1; shift>=0; shift--)
   {
      zz[shift]=zzL[shift];
      res=zzH[shift];
      if(res!=0.0) zz[shift]=res;
   }

   if (ExtLabel>0)
   {
      for(shift=Bars-1; shift>=0; shift--)
      {
         if (zz[shift]>0)
         {
            if (zzH[shift]>0)
            {
               peak=High[shift]; wrpeak=Low[shift];
               ha[shift]=High[shift]; la[shift]=0;
               metka=2; shift--;
            }
            else
            {
               peak=Low[shift]; wrpeak=High[shift];
               la[shift]=Low[shift]; ha[shift]=0;
               metka=1; shift--;
            }
         }

         if (metka==1)
         {
            if (wrpeak<High[shift])
            {
               if (High[shift]-peak>minSize*Point) {metka=0;  ha[shift]=High[shift];}
            }
            else
            {
               wrpeak=High[shift];
            }
         }
         else if (metka==2)
         {
            if (wrpeak>Low[shift])
            {
               if (peak-Low[shift]>minSize*Point) {metka=0;  la[shift]=Low[shift];}
            }
            else
            {
               wrpeak=Low[shift];
            }
         }
      }
   }
}

// SQZZ算法 - 完整版本（从主程序移植）
void ZigZag_SQZZ(bool zzFill=true)
{  
   static int act_time=0, H1=10000,L1=10000,H2=10000,H3=10000,H4=10000,L2=10000,L3=10000,L4=10000;	
   static double H1p=-1,H2p=-1,H3p=-1, H4p=-1, L1p=10000,L2p=10000,L3p=10000,L4p=10000;
   int mnm=1,tb,sH,sL,sX, i, a, barz, b,c, ii, H,L;	
   double val,x,Lp,Hp,k=0.;   
   
   if(Bars<100) return; 
   
   barz=Bars-4;
   int bb=barz;
   if(minBars==0)minBars=minSize;	
   if(minSize==0)minSize=minBars*3; 
   tb=MathSqrt(minSize*minBars);
   mnm=tb;
   a=time2bar(act_time);	
   b=barz;
   
   if(a>=0 && a<tb)
   {
      ii=a; a--; L1+=a; H1+=a;
      L2+=a; H2+=a; L3+=a; H3+=a;
      if(!zzFill)
      {
         for(i=barz; i>=a; i--) {zzH[i]=zzH[i-a]; zzL[i]=zzL[i-a];}
         for(;i>=0;i--) {zzH[i]=0; zzL[i]=0;}
      }
   }
   else
   {
      ii=barz;
      H1=ii+1; L1=ii;
      H2=ii+3; L2=ii+2;
      L2p=Low[L2];H2p=High[H2];	
      L1p=Low[L1];H1p=High[H1];
      H3=H2; H3p=H2p;
      L3=L2; L3p=L2p;
   }
   act_time=Time[1];

   for(c=0; ii>=0; c++, ii--)
   {
      H=ii; L=ii; Hp=High[H]; Lp=Low[L];

      if(H2<L2)
      {
         if( Hp>=H1p )
         {
            H1=H; H1p=Hp;
            if( H1p>H2p )
            {
               zzH[H2]=0;
               H1=H; H1p=Hp;
               H2=H1; H2p=H1p;
               L1=H1; L1p=H1p;
               zzH[H2]=H2p;
            }
         }
         else if( Lp<=L1p )
         {
            L1=L; L1p=Lp;
            x=ray_value(L2,L2p,H2+(L2-H3)*0.5,H2p+(L2p-H3p)*0.5,L1);
            if( L1p<=L2p || tb*tb*Point<(H2p-L1p)*(H2-L1))
            {
               L4=L3; L4p=L3p;
               L3=L2; L3p=L2p;
               L2=L1; L2p=L1p;
               H1=L1; H1p=L1p;
               zzL[L2]=L2p;
            }
         }
      }

      if(L2<H2) 
      {
         if( Lp<=L1p )
         {
            L1=L; L1p=Lp;
            if( L1p<=L2p )
            {
               zzL[L2]=0;
               L1=L; L1p=Lp;
               L2=L1; L2p=L1p;
               H1=L1; H1p=L1p;
               zzL[L2]=L2p;
            }
         }
         else if( Hp>=H1p )
         {
            H1=H; H1p=Hp;
            x=ray_value(H2,H2p,L2+0.5*(H2-L3),L2p+0.5*(H2p-L3p),H1);
            if( H1p>=H2p || tb*tb*Point<(H1p-L2p)*(L2-H1))
            {
               H4=H3; H4p=H3p;
               H3=H2; H3p=H2p;
               H2=H1; H2p=H1p;
               L1=H1; L1p=H1p;
               zzH[H2]=H2p;
            }
         }
      }
   }
   for(ii=bb-1; ii>=0; ii--) zz[ii]=MathMax(zzL[ii],zzH[ii]);
}

//+------------------------------------------------------------------+
//| 特殊ZigZag算法                                                    |
//+------------------------------------------------------------------+

/**
 * Ensign ZigZag算法 - 完整版本
 * 功能：基于趋势确认的专业ZigZag算法
 * 复杂度：约200行算法逻辑
 * 特点：考虑收盘价确认和反向信号过滤
 */
void Ensign_ZZ()
{
   int i,n;

   if (ExtMaxBar>0) cbi=ExtMaxBar; else cbi=Bars-1;

   for (i=cbi; i>=ExtMinBar; i--) 
   {
      if (lLast==0) {lLast=Low[i];hLast=High[i]; if (ExtIndicator==3) di=hLast-lLast;}

      if (fs==0)
      {
         if (lLast<Low[i] && hLast<High[i]) {fs=1; hLast=High[i]; si=High[i]; ai=i; tai=Time[i]; if (ExtIndicator==3) di=High[i]-Low[i];}
         if (lLast>Low[i] && hLast>High[i]) {fs=2; lLast=Low[i]; si=Low[i]; bi=i; tbi=Time[i]; if (ExtIndicator==3) di=High[i]-Low[i];}
      }

      if (ti<Time[i])
      {
         ti=Time[i];
         ai0=iBarShift(Symbol(),Period(),tai); 
         bi0=iBarShift(Symbol(),Period(),tbi);

         fcount0=false;
         if ((fh || fl) && countBar>0) {countBar--; if (i==0 && countBar==0) fcount0=true;}

         if (fs==1)
         {
            if (hLast>High[i] && !fh) fh=true;

            if (i==0)
            {
               if (Close[i+1]<lLast && fh) {fs=2; countBar=minBars; fh=false;}
               if (countBar==0 && si-di>Low[i+1] && High[i+1]<hLast && ai0>i+1 && fh && !fcount0) {fs=2; countBar=minBars; fh=false;}

               if (fs==2)
               {
                  zz[ai0]=High[ai0];
                  zzH[ai0]=High[ai0];
                  lLast=Low[i+1];
                  if (ExtIndicator==3) di=High[i+1]-Low[i+1];
                  si=Low[i+1];
                  bi=i+1;
                  tbi=Time[i+1];
                  if (ExtLabel>0)
                  {
                     ha[ai0]=High[ai0];
                     tml=Time[i+1]; ha[i+1]=0; la[i+1]=Low[i+1];
                  }
                  else if (chHL && chHL_PeakDet_or_vts) {ha[i+1]=si+di; la[i+1]=si;}
               }
            }
            else
            {
               if (Close[i]<lLast && fh) {fs=2; countBar=minBars; fh=false;}
               if (countBar==0 && si-di>Low[i] && High[i]<hLast && fh) {fs=2; countBar=minBars; fh=false;}

               if (fs==2)
               {
                  zz[ai]=High[ai];
                  zzH[ai]=High[ai];
                  lLast=Low[i];
                  if (ExtIndicator==3) di=High[i]-Low[i];
                  si=Low[i];
                  bi=i;
                  tbi=Time[i];
                  if (ExtLabel>0)
                  {
                     ha[ai]=High[ai];
                     tml=Time[i]; ha[i]=0; la[i]=Low[i];
                  }
                  else if (chHL && chHL_PeakDet_or_vts) {ha[i]=si+di; la[i]=si;}
               }
            }
         }
         else
         {
            if (lLast<Low[i] && !fl) fl=true;

            if (i==0)
            {
               if (Close[i+1]>hLast && fl) {fs=1; countBar=minBars; fl=false;}
               if (countBar==0 && si+di<High[i+1] && Low[i+1]>lLast && bi0>i+1 && fl && !fcount0) {fs=1; countBar=minBars; fl=false;}

               if (fs==1)
               {
                  zz[bi0]=Low[bi0];
                  zzL[bi0]=Low[bi0];
                  hLast=High[i+1];
                  if (ExtIndicator==3) di=High[i+1]-Low[i+1];
                  si=High[i+1];
                  ai=i+1;
                  tai=Time[i+1];
                  if (ExtLabel>0)
                  {
                     la[bi0]=Low[bi0];
                     tmh=Time[i+1]; ha[i+1]=High[i+1]; la[i+1]=0;
                  }
                  else if (chHL && chHL_PeakDet_or_vts) {ha[i+1]=si; la[i+1]=si-di;}
               }
            }
            else
            {
               if (Close[i]>hLast && fl) {fs=1; countBar=minBars; fl=false;}
               if (countBar==0 && si+di<High[i] && Low[i]>lLast && fl) {fs=1; countBar=minBars; fl=false;}

               if (fs==1)
               {
                  zz[bi]=Low[bi];
                  zzL[bi]=Low[bi];
                  hLast=High[i];
                  if (ExtIndicator==3) di=High[i]-Low[i];
                  si=High[i];
                  ai=i;
                  tai=Time[i];
                  if (ExtLabel>0)
                  {
                     la[bi]=Low[bi];
                     tmh=Time[i]; ha[i]=High[i]; la[i]=0;
                  }
                  else if (chHL && chHL_PeakDet_or_vts==1) {ha[i]=si; la[i]=si-di;}
               }
            }
         }
      } 

      if (fs==1 && High[i]>si) {ai=i; tai=Time[i]; hLast=High[i]; si=High[i]; countBar=minBars; fh=false; if (ExtIndicator==3) di=High[i]-Low[i];}

      if (fs==2 && Low[i]<si) {bi=i; tbi=Time[i]; lLast=Low[i]; si=Low[i]; countBar=minBars; fl=false; if (ExtIndicator==3) di=High[i]-Low[i];}

      if (chHL && chHL_PeakDet_or_vts && ExtLabel==0)
      {
         if (fs==1) {ha[i]=si; la[i]=si-di;}
         if (fs==2) {ha[i]=si+di; la[i]=si;}
      } 

      if (i==0) 
      {
         ai0=iBarShift(Symbol(),Period(),tai); 
         bi0=iBarShift(Symbol(),Period(),tbi);

         if (fs==1)
         {
            for (n=bi0-1; n>=0; n--) {zzH[n]=0; zz[n]=0; if (ExtLabel>0) ha[n]=0;} 
            zz[ai0]=High[ai0]; zzH[ai0]=High[ai0]; zzL[ai0]=0; if (ExtLabel>0) ha[ai0]=High[ai0];
         }
         if (fs==2)
         {
            for (n=ai0-1; n>=0; n--) {zzL[n]=0; zz[n]=0; if (ExtLabel>0) la[n]=0;} 
            zz[bi0]=Low[bi0]; zzL[bi0]=Low[bi0]; zzH[bi0]=0; if (ExtLabel>0) la[bi0]=Low[bi0];
         }

         if (ExtLabel>0)
         {
            if (fs==1) {aim=iBarShift(Symbol(),0,tmh); if (aim<bi0) ha[aim]=High[aim];}
            else if (fs==2) {bim=iBarShift(Symbol(),0,tml); if (bim<ai0) la[bim]=Low[bim];}
         }
      }
   }
}

// nenZigZag算法 - 完整版本（从主程序移植）
void nenZigZag()
{
   if (cbi>0)
   {
      datetime nen_time=iTime(NULL,GrossPeriod,0);
      int i=0, j=0;
      double nen_dt=0, last_j=0, last_nen=0;
      int limit, big_limit, bigshift=0;

      int i_metka=-1, i_metka_m=-1, k, m, jm;
      bool fl_metka=false;
      double last_jm=0, last_nen_m=0;

      if (ExtMaxBar>0) _maxbarZZ=ExtMaxBar; else _maxbarZZ=Bars;

      if (init_zz)
      {
         limit=_maxbarZZ-1;
         big_limit=iBars(NULL,GrossPeriod)-1;
      }
      else
      {
         limit=iBarShift(NULL,0,afr[2]);
         big_limit=iBarShift(NULL,GrossPeriod,afr[2]);
      }

      while (bigshift<big_limit && i<limit)
      {
         if (Time[i]>=nen_time)
         {
            if (ExtIndicator==6)
            {
               if (ExtLabel>0)
               {
                  ha[i]=iCustom(NULL,GrossPeriod,"ZigZag_new_nen4",minBars,ExtDeviation,ExtBackstep,1,1,bigshift);
                  la[i]=iCustom(NULL,GrossPeriod,"ZigZag_new_nen4",minBars,ExtDeviation,ExtBackstep,1,2,bigshift);
               }
               nen_ZigZag[i]=iCustom(NULL,GrossPeriod,"ZigZag_new_nen4",minBars,ExtDeviation,ExtBackstep,0,0,bigshift);
            }
            else  if (ExtIndicator==7)
            {
               if (ExtLabel>0)
               {
                  ha[i]=iCustom(NULL,GrossPeriod,"DT_ZZ_nen",minBars,1,1,bigshift);
                  la[i]=iCustom(NULL,GrossPeriod,"DT_ZZ_nen",minBars,1,2,bigshift);
               }
               nen_ZigZag[i]=iCustom(NULL,GrossPeriod,"DT_ZZ_nen",minBars,0,0,bigshift);
            }
            else  if (ExtIndicator==8) nen_ZigZag[i]=iCustom(NULL,GrossPeriod,"CZigZag",minBars,ExtDeviation,0,bigshift);
            else  if (ExtIndicator==10)
            {
               if (ExtLabel>0)
               {
                  ha[i]=iCustom(NULL,GrossPeriod,"Swing_ZZ_1",minBars,1,1,bigshift);
                  la[i]=iCustom(NULL,GrossPeriod,"Swing_ZZ_1",minBars,1,2,bigshift);
               }
               nen_ZigZag[i]=iCustom(NULL,GrossPeriod,"Swing_ZZ_1",minBars,1,0,bigshift);
            }
            i++;
         }
         else {bigshift++;nen_time=iTime(NULL,GrossPeriod,bigshift);}
      }

      if (init_zz)
      {
         double i1=0, i2=0;
         init_zz=false;

         for (i=limit;i>ExtMinBar;i--)
         {
            if (nen_ZigZag[i]>0)
            {
               if (i1==0) i1=nen_ZigZag[i];
               else if (i1>0 && i1!=nen_ZigZag[i]) i2=nen_ZigZag[i];
               if (i2>0) 
               {
                  if (i1>i2) hi_nen=true;
                  else hi_nen=false;
                  break;
               }
            }
         }
      }
      else
      {
         if (afrl[2]>0) hi_nen=false; else hi_nen=true;
      }

      for (i=limit;i>=0;i--)
      {
         {zz[i]=0; zzH[i]=0; zzL[i]=0;}

         if (nen_ZigZag[i]>0)
         {
            if (ExtLabel==2)
            {
               if (i_metka_m>=0 && !fl_metka)
               {
                  m=i_metka_m-GrossPeriod/Period();

                  for (k=i_metka_m; k>m; k--)
                  {
                     ha[k]=0; la[k]=0;
                  }

                  if (hi_nen) ha[jm]=last_nen_m;
                  else la[jm]=last_nen_m;
                  jm=0; last_nen_m=0; last_jm=0; i_metka_m=-1;
               }

               if (i_metka<0) i_metka=i;
            }

            fl_metka=true;

            if (nen_dt>0 && nen_dt!=nen_ZigZag[i])
            {
               if (i_metka>=0 && fl_metka)
               {
                  m=i_metka-GrossPeriod/Period();
                  for (k=i_metka; k>m; k--)
                  {
                     ha[k]=0; la[k]=0;
                  }
                  if (hi_nen) ha[j]=last_nen;
                  else la[j]=last_nen;
                  i_metka=i;
               }

               if (hi_nen) {hi_nen=false;zzH[j]=last_nen;}
               else {hi_nen=true;zzL[j]=last_nen;}
               last_j=0;nen_dt=0;zz[j]=last_nen;
            }

            if (hi_nen)
            {
               nen_dt=nen_ZigZag[i];
               if (last_j<High[i]) {j=i;last_j=High[i];last_nen=nen_ZigZag[i];}
            }
            else
            {
               nen_dt=nen_ZigZag[i];
               if (last_j==0) {j=i;last_j=Low[i];last_nen=nen_ZigZag[i];}
               if (last_j>Low[i]) {j=i;last_j=Low[i];last_nen=nen_ZigZag[i];}
            }

            if (nen_dt>0 && i==0)
            {
               if (i_metka>=0 && fl_metka)
               {
                  m=i_metka-GrossPeriod/Period();
                  for (k=i_metka; k>m; k--)
                  {
                     ha[k]=0; la[k]=0;
                  }
                  if (hi_nen) ha[j]=last_nen;
                  else la[j]=last_nen;
                  fl_metka=false;
               }

               zz[j]=last_nen;
               if (hi_nen) zzH[j]=last_nen; else zzL[j]=last_nen;
            }
         }
         else
         {
            if (last_j>0 && fl_metka)
            {
               if (i_metka>=0 && fl_metka)
               {
                  m=i_metka-GrossPeriod/Period();

                  for (k=i_metka; k>m; k--)
                  {
                     ha[k]=0; la[k]=0;
                  }
                  if (hi_nen) ha[j]=last_nen;
                  else la[j]=last_nen;
               }

               fl_metka=false;

               if (hi_nen) {hi_nen=false;zzH[j]=last_nen;}
               else {hi_nen=true;zzL[j]=last_nen;}
               last_j=0;nen_dt=0;zz[j]=last_nen;
               i_metka=-1;
            }

            if (ExtLabel==2)
            {
               if ((ha[i]>0 || la[i]>0) && !fl_metka)
               {
                  if (i_metka_m<0)
                  { 
                     i_metka_m=i; jm=i;
                     if (hi_nen)
                     {
                        last_jm=High[i];last_nen_m=ha[i];
                     }
                     else
                     {
                        last_jm=Low[i];last_nen_m=la[i];
                     }
                  }

                  if (hi_nen)
                  {
                     if (last_nen_m>last_jm) {jm=i;last_jm=High[i];}
                  }
                  else
                  {
                     if (last_nen_m<last_jm) {jm=i;last_jm=Low[i];}
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ZigZag辅助算法                                                    |
//+------------------------------------------------------------------+

// ZZTalex算法 - 完整版本（从主程序移植）
void ZZTalex(int n)
{
   // ZZTalex ZigZag算法实现
   int    i,j,k,zzbarlow,zzbarhigh,curbar,curbar1,curbar2,EP,Mbar[];
   double curpr,Mprice[];
   bool flag,fd;
   
   ArrayInitialize(zz,0);ArrayInitialize(zzL,0);ArrayInitialize(zzH,0);
   
   EP=ExtPoint;
   zzbarlow=iLowest(NULL,0,MODE_LOW,n,0);        
   zzbarhigh=iHighest(NULL,0,MODE_HIGH,n,0);     
   
   if(zzbarlow<zzbarhigh) {curbar=zzbarlow; curpr=Low[zzbarlow];}
   if(zzbarlow>zzbarhigh) {curbar=zzbarhigh; curpr=High[zzbarhigh];}
   if(zzbarlow==zzbarhigh){curbar=zzbarlow;curpr=funk1(zzbarlow, n);}
   
   ArrayResize(Mbar,ExtPoint);
   ArrayResize(Mprice,ExtPoint);
   j=0;
   endpr=curpr;
   endbar=curbar;
   Mbar[j]=curbar;
   Mprice[j]=curpr;
   
   EP--;
   if(curpr==Low[curbar]) flag=true;
   else flag=false;
   fl=flag;
 
   i=curbar+1;
   while(EP>0)
   {
    if(flag)
    {
     while(i<=Bars-1)
     {
     curbar1=iHighest(NULL,0,MODE_HIGH,n,i); 
     curbar2=iHighest(NULL,0,MODE_HIGH,n,curbar1); 
     if(curbar1==curbar2){curbar=curbar1;curpr=High[curbar];flag=false;i=curbar+1;j++;break;}
     else i=curbar2;
     }
     
     Mbar[j]=curbar;
     Mprice[j]=curpr;
     EP--;
     
    }
    
    if(EP==0) break;
    
    if(!flag) 
    {
     while(i<=Bars-1)
     {
     curbar1=iLowest(NULL,0,MODE_LOW,n,i); 
     curbar2=iLowest(NULL,0,MODE_LOW,n,curbar1); 
     if(curbar1==curbar2){curbar=curbar1;curpr=Low[curbar];flag=true;i=curbar+1;j++;break;}
     else i=curbar2;
     }
     
     Mbar[j]=curbar;
     Mprice[j]=curpr;
     EP--;
    }
   }
   
   if(Mprice[0]==Low[Mbar[0]])fd=true; else fd=false;
   for(k=0;k<=ExtPoint-1;k++)
   {
    if(k==0)
    {
     if(fd==true)
      {
       Mbar[k]=iLowest(NULL,0,MODE_LOW,Mbar[k+1]-Mbar[k],Mbar[k]);Mprice[k]=Low[Mbar[k]];endbar=minBars;
      }
     if(fd==false)
      {
       Mbar[k]=iHighest(NULL,0,MODE_HIGH,Mbar[k+1]-Mbar[k],Mbar[k]);Mprice[k]=High[Mbar[k]];endbar=minBars;
      }
    }
    if(k<ExtPoint-2)
    {
     if(fd==true)
      {
       Mbar[k+1]=iHighest(NULL,0,MODE_HIGH,Mbar[k+2]-Mbar[k]-1,Mbar[k]+1);Mprice[k+1]=High[Mbar[k+1]];
      }
     if(fd==false)
      {
       Mbar[k+1]=iLowest(NULL,0,MODE_LOW,Mbar[k+2]-Mbar[k]-1,Mbar[k]+1);Mprice[k+1]=Low[Mbar[k+1]];
      }
    }
    if(fd==true)fd=false;else fd=true;
    
    zz[Mbar[k]]=Mprice[k];

    if (k==0)
      {
       if (Mprice[k]>Mprice[k+1])
         {
          zzH[Mbar[k]]=Mprice[k];
         }
       else
         {
          zzL[Mbar[k]]=Mprice[k];
         }
      }
    else
      {
       if (Mprice[k]>Mprice[k-1])
         {
          zzH[Mbar[k]]=Mprice[k];
         }
       else
         {
          zzL[Mbar[k]]=Mprice[k];
         }
      }
   }
}

// ZZ_2L_nen算法 - 完整版本（从主程序移植）
void ZZ_2L_nen()
{
   int count = IndicatorCounted();
   int k, i, shift, cnt, pos, curhighpos, curlowpos;

   if (Bars-count-1>2) 
   {
      count=0; NewBarTime=0; countbars=0; realcnt=0;
      ArrayInitialize(zz,0); ArrayInitialize(zzL,0); ArrayInitialize(zzH,0);
   }
   
   for (k=(Bars-count-1);k>=0;k--)
   {
      if((NewBarTime==Time[0]) || (realcnt==Bars))
         first=false; 
      else 
         first=true;
     
      if (first)    
      {
         lastlowpos=Bars-1;
         lasthighpos=Bars-1;
         zzL[Bars-1]=0.0;
         zzH[Bars-1]=0.0;
         zz[Bars-1]=0.0;
         realcnt=2;
      
         for(shift=(Bars-2); shift>=0; shift--)
         {
            if ((High[shift]>High[shift+1]) && (Low[shift]>=Low[shift+1])) 
            {
               zzL[shift]=0.0;
               zzH[shift]=High[shift];
               zz[shift]=High[shift];
               lasthighpos=shift;
               lasthigh=High[shift];
               lastlow=Low[Bars-1];
               pos=shift;
               first=false;
               break;          
            }
            if ((High[shift]<=High[shift+1]) && (Low[shift]<Low[shift+1])) 
            {
               zzL[shift]=Low[shift];
               zzH[shift]=0.0;
               zz[shift]=Low[shift];
               lasthigh=High[Bars-1];
               lastlowpos=shift;
               lastlow=Low[shift];
               pos=shift;
               first=false;
               break;
            }
            if ((High[shift]>High[shift+1]) && (Low[shift]<Low[shift+1])) 
            {
               if ((High[shift]-High[shift+1])>(Low[shift+1]-Low[shift]))
               {
                  zzL[shift]=0.0;
                  zzH[shift]=High[shift];
                  zz[shift]=High[shift];
                  zzL[shift]=0.0;
                  lasthighpos=shift;
                  lasthigh=High[shift];
                  lastlow=Low[Bars-1];
                  pos=shift;
                  first=false;
                  break;
               }
               if ((High[shift]-High[shift+1])<(Low[shift+1]-Low[shift]))
               {
                  zzL[shift]=Low[shift];
                  zzH[shift]=0.0;
                  zz[shift]=Low[shift];
                  lasthighpos=shift;
                  lasthigh=High[shift];
                  lastlow=Low[Bars-1];
                  pos=shift;
                  first=false;
                  break;
               } 
               if ((High[shift]-High[shift+1])==(Low[shift+1]-Low[shift]))
               {
                  zzL[shift]=0.0;
                  zzH[shift]=0.0;
                  zz[shift]=0.0;
               } 
            }
            if ((High[shift]<High[shift+1]) && (Low[shift]>Low[shift+1])) 
            {
               zzL[shift]=0.0;
               zzH[shift]=0.0;
               zz[shift]=0.0;
            }  
         }   
         pos=shift;
         realcnt=realcnt+1;   
         
         for(shift=pos-1; shift>=0; shift--)
         {
            if ((High[shift]>High[shift+1]) && (Low[shift]>=Low[shift+1]))
            {
               if (lasthighpos<lastlowpos)
               {
                  if (High[shift]>High[lasthighpos])
                  {
                     zzL[shift]=0.0;
                     zzH[shift]=High[shift];
                     zz[shift]=High[shift];
                     zz[lasthighpos]=0.0;
                     if (shift!=0)
                        lasthighpos=shift;
                     lasthigh=High[shift];
                     if (lastlowpos!=Bars) 
                     {
                     }
                  }  
               } 
               if (lasthighpos>lastlowpos) 
               {
                  if ((((High[shift]-Low[lastlowpos])>(StLevel*Point)) && ((lastlowpos-shift)>=minBars)) ||
                       ((High[shift]-Low[lastlowpos])>=(BigLevel*Point))) 
                  {
                     zzL[shift]=0.0;
                     zzH[shift]=High[shift];
                     zz[shift]=High[shift];
                     if (shift!=0)
                        lasthighpos=shift;
                     lasthigh=High[shift]; 
                  }
               }    
            }
            if ((High[shift]<=High[shift+1]) && (Low[shift]<Low[shift+1]))
            {
               if (lastlowpos<lasthighpos)
               {
                  if (Low[shift]<Low[lastlowpos])
                  { 
                     zzL[shift]=Low[shift];
                     zzH[shift]=0.0;
                     zz[shift]=Low[shift];
                     zz[lastlowpos]=0.0;
                     if (shift!=0)
                        lastlowpos=shift;
                     lastlow=Low[shift];
                  }
               }
               if (lastlowpos>lasthighpos)
               {
                  if ((((High[lasthighpos]-Low[shift])>(StLevel*Point)) && ((lasthighpos-shift)>=minBars)) ||
                       ((High[lasthighpos]-Low[shift])>=(BigLevel*Point))) 
                  {
                     zzL[shift]=Low[shift];
                     zzH[shift]=0.0;
                     zz[shift]=Low[shift];
                     if (shift!=0)
                        lastlowpos=shift;
                     lastlow=Low[shift]; 
                  }
               } 
            }
            if ((High[shift]>High[shift+1]) && (Low[shift]<Low[shift+1]))
            {
               if (lastlowpos<lasthighpos)
               {
                  if (Low[shift]<Low[lastlowpos])
                  {
                     zzL[shift]=Low[shift];
                     zzH[shift]=0.0;
                     zz[shift]=Low[shift];
                     zz[lastlowpos]=0.0;
                     if (shift!=0) 
                        lastlowpos=shift;
                     lastlow=Low[shift];
                  } 
               }
               if (lasthighpos<lastlowpos) 
               {
                  if (High[shift]>High[lasthighpos])
                  {
                     zzL[shift]=0.0;
                     zzH[shift]=High[shift];
                     zz[shift]=High[shift];
                     zz[lasthighpos]=0.0;
                     if (shift!=0)
                        lasthighpos=shift;
                     lasthigh=High[shift];
                  }
               }
            } 
            realcnt=realcnt+1; 
         }
        
         first=false; 
         countbars=Bars;
         NewBarTime=Time[0];
      }
      else
      { 
         if (realcnt!=Bars)
         {
            first=True;
            return;
         } 
        
         if (Close[0]>=lasthigh) 
         {
            if (lastlowpos<lasthighpos)
            {
               if (Low[0]>lastlow)
               {
                  if ((((High[0]-Low[lastlowpos])>(StLevel*Point)) && ((lastlowpos)>=minBars)) ||
                       ((High[0]-Low[lastlowpos])>(BigLevel*Point))) 
                  {
                     zzL[0]=0.0;
                     zzH[0]=High[0];
                     zz[0]=High[0]; 
                     lasthigh=High[0];
                  }
               }
            }
            if (lastlowpos>lasthighpos)
            {
               if (High[0]>=lasthigh)
               {
                  zz[lasthighpos]=0.0;
                  zz[0]=High[0];
                  zzL[0]=0.0;
                  zzH[0]=High[0];
                  lasthighpos=0;
                  lasthigh=High[0];
               }
            }  
         }
         if (Close[0]<=lastlow) 
         {
            if (lastlowpos<lasthighpos)
            {
               zz[lastlowpos]=0.0;
               zz[0]=Low[0];
               zzL[0]=Low[0];
               zzH[0]=0.0;
               lastlow=Low[0];
               lastlowpos=0;  
            }
            if (lastlowpos>lasthighpos)
            {
               if (High[0]<lasthigh)
               {
                  if ((((High[lasthighpos]-Low[shift])>(StLevel*Point)) && ((lasthighpos-shift)>=minBars)) ||
                       ((High[lasthighpos]-Low[shift])>(BigLevel*Point)))
                  {
                     zz[0]=Low[0];
                     zzL[0]=Low[0];
                     zzH[0]=0.0;
                     lastlow=Low[0];
                  } 
               }
            }  
         }
      }  
   }
}

//+------------------------------------------------------------------+
//| 角度和波动分析                                                    |
//+------------------------------------------------------------------+

/**
 * 角度自适应ZigZag算法 - 完整版本
 * 功能：基于价格角度变化的高级ZigZag识别
 * 复杂度：约150行算法逻辑
 * 特点：考虑价格变化角度，提供更精确的转折点识别
 */
void ang_AZZ_()
{
   int i,n;

   if (ExtMaxBar>0) cbi=ExtMaxBar; else cbi=Bars-1;

   for (i=cbi; i>=ExtMinBar; i--) 
   {
      if (ti<Time[i]) {fsp=fs; sip=si;} ti=Time[i];

      if (minSize==0 && minPercent!=0) di=minPercent*Close[i]/2/100;

      if (High[i]>si+di && Low[i]<si-di)
      {
         if (fs==1) si=High[i]-di;
         if (fs==2) si=Low[i]+di;
      } 
      else
      {
         if (fs==1)
         {
            if (High[i]>=si+di) si=High[i]-di;
            else if (Low[i]<si-di) si=Low[i]+di;
         }
         if (fs==2)
         {
            if (Low[i]<=si-di) si=Low[i]+di;
            else if (High[i]>si+di) si=High[i]-di;
         }
      }

      if (i>cbi-1) {si=(High[i]+Low[i])/2;}

      if (si>sip) fs=1;
      if (si<sip) fs=2;

      if (fs==1 && fsp==2)
      {
         hm=High[i];
         bi=iBarShift(Symbol(),Period(),tbi);
         zz[bi]=Low[bi];
         zzL[bi]=Low[bi];
         tai=Time[i];
         fsp=fs;
         si=High[i]-di;
         sip=si;
         if (ExtLabel>0)
         {
            ha[i]=High[i]; la[bi]=Low[bi]; la[i]=0;
            tmh=Time[i]; ha[i]=High[i]; la[i]=0;
         }
      }

      if (fs==2 && fsp==1)
      {
         lm=Low[i]; 
         ai=iBarShift(Symbol(),Period(),tai); 
         zz[ai]=High[ai];
         zzH[ai]=High[ai];
         tbi=Time[i];
         si=Low[i]+di;
         fsp=fs;
         sip=si;
         if (ExtLabel>0)
         {
            ha[ai]=High[ai]; ha[i]=0; la[i]=Low[i];
            tml=Time[i]; ha[i]=0; la[i]=Low[i];
         }
      }

      if (fs==1 && High[i]>hm) 
         {hm=High[i]; tai=Time[i]; si=High[i]-di;}
      if (fs==2 && Low[i]<lm) 
         {lm=Low[i]; tbi=Time[i]; si=Low[i]+di;}

      if (chHL && chHL_PeakDet_or_vts && ExtLabel==0) {ha[i]=si+di; la[i]=si-di;} 

      if (i==0) 
      {
         ai0=iBarShift(Symbol(),Period(),tai); 
         bi0=iBarShift(Symbol(),Period(),tbi);
         if (fs==1)
         {
            for (n=bi0-1; n>=0; n--) {zzH[n]=0; zz[n]=0; if (ExtLabel>0) ha[n]=0;}
            zz[ai0]=High[ai0]; zzH[ai0]=High[ai0]; zzL[ai0]=0; if (ExtLabel>0) ha[ai0]=High[ai0];
         }
         if (fs==2)
         {
            for (n=ai0-1; n>=0; n--) {zzL[n]=0; zz[n]=0; if (ExtLabel>0) la[n]=0;}
            zz[bi0]=Low[bi0]; zzL[bi0]=Low[bi0]; zzH[bi0]=0; if (ExtLabel>0) la[bi0]=Low[bi0];
         }

         if (ExtLabel>0)
         {
            if (fs==1) {aim=iBarShift(Symbol(),0,tmh); if (aim<bi0) ha[aim]=High[aim];}
            else if (fs==2) {bim=iBarShift(Symbol(),0,tml); if (bim<ai0) la[bim]=Low[bim];}
         }
      }
   }
}

// Gann Swing分析 - 完整版本（从主程序移植）
void GannSwing()
{
   int i,n;

   double lLast_m=0, hLast_m=0;
   int countBarExt=0;
   int countBarl=0,countBarh=0;
   fs=0; ti=0;

   ArrayInitialize(zz,0.0);
   ArrayInitialize(zzL,0.0);
   ArrayInitialize(zzH,0.0);
   if (ExtLabel>0)
   {
      ArrayInitialize(la,0.0);
      ArrayInitialize(ha,0.0);
   }

   if (ExtMaxBar>0) cbi=ExtMaxBar; else cbi=Bars-1;
   for (i=cbi; i>=ExtMinBar; i--) 
   {
      if (lLast==0) {lLast=Low[i]; hLast=High[i]; ai=i; bi=i;}
      if (ti!=Time[i])
      {
         ti=Time[i];
         if (lLast_m==0 && hLast_m==0)
         {
            if (lLast>Low[i] && hLast<High[i])
            {
               lLast=Low[i];hLast=High[i];lLast_m=Low[i];hLast_m=High[i];countBarExt++;
               if (fs==1) {countBarl=countBarExt; ai=i; tai=Time[i];}
               else if (fs==2) {countBarh=countBarExt; bi=i; tbi=Time[i];}
               else {countBarl++;countBarh++;}
            }
            else if (lLast<=Low[i] && hLast<High[i])
            {
               lLast_m=0;hLast_m=High[i];countBarl=0;countBarExt=0;
               if (fs!=1) countBarh++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; ai=i; tai=Time[i];}
            }
            else if (lLast>Low[i] && hLast>=High[i])
            {
               lLast_m=Low[i];hLast_m=0;countBarh=0;countBarExt=0;
               if (fs!=2) countBarl++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; bi=i; tbi=Time[i];}
            }
         }
         else  if (lLast_m>0 && hLast_m>0)
         {
            if (lLast_m>Low[i] && hLast_m<High[i])
            {
               lLast=Low[i];hLast=High[i];lLast_m=Low[i];hLast_m=High[i];countBarExt++;
               if (fs==1) {countBarl=countBarExt; ai=i; tai=Time[i];}
               else if (fs==2) {countBarh=countBarExt; bi=i; tbi=Time[i];}
               else {countBarl++;countBarh++;}
            }
            else if (lLast_m<=Low[i] && hLast_m<High[i])
            {
               lLast_m=0;hLast_m=High[i];countBarl=0;countBarExt=0;
               if (fs!=1) countBarh++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; ai=i; tai=Time[i];}
            }
            else if (lLast_m>Low[i] && hLast_m>=High[i])
            {
               lLast_m=Low[i];hLast_m=0;countBarh=0;countBarExt=0;
               if (fs!=2) countBarl++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; bi=i; tbi=Time[i];}
            }
         }
         else  if (lLast_m>0)
         {
            if (lLast_m>Low[i] && hLast<High[i])
            {
               lLast=Low[i];hLast=High[i];lLast_m=Low[i];hLast_m=High[i];countBarExt++;
               if (fs==1) {countBarl=countBarExt; ai=i; tai=Time[i];}
               else if (fs==2) {countBarh=countBarExt; bi=i; tbi=Time[i];}
               else {countBarl++;countBarh++;}
            }
            else if (lLast_m<=Low[i] && hLast<High[i])
            {
               lLast_m=0;hLast_m=High[i];countBarl=0;countBarExt=0;
               if (fs!=1) countBarh++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; ai=i; tai=Time[i];}
            }
            else if (lLast_m>Low[i] && hLast>=High[i])
            {
               lLast_m=Low[i];hLast_m=0;countBarh=0;countBarExt=0;
               if (fs!=2) countBarl++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; bi=i; tbi=Time[i];}
            }
         }
         else  if (hLast_m>0)
         {
            if (lLast>Low[i] && hLast_m<High[i])
            {
               lLast=Low[i];hLast=High[i];lLast_m=Low[i];hLast_m=High[i];countBarExt++;
               if (fs==1) {countBarl=countBarExt; ai=i; tai=Time[i];}
               else if (fs==2) {countBarh=countBarExt; bi=i; tbi=Time[i];}
               else {countBarl++;countBarh++;}
            }
            else if (lLast<=Low[i] && hLast_m<High[i])
            {
               lLast_m=0;hLast_m=High[i];countBarl=0;countBarExt=0;
               if (fs!=1) countBarh++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; ai=i; tai=Time[i];}
            }
            else if (lLast>Low[i] && hLast_m>=High[i])
            {
               lLast_m=Low[i];hLast_m=0;countBarh=0;countBarExt=0;
               if (fs!=2) countBarl++;
               else {lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0; bi=i; tbi=Time[i];}
            }
         }

         if (fs==0)
         {
            if (lLast<lLast_m && hLast>hLast_m)
            {
               lLast=Low[i]; hLast=High[i]; ai=i; bi=i; countBarl=0;countBarh=0;countBarExt=0;
            }
              
            if (countBarh>countBarl && countBarh>countBarExt && countBarh>minBars)
            {
               lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0;
               fs=1;countBarh=0;countBarl=0;countBarExt=0;
               zz[bi]=Low[bi];
               zzL[bi]=Low[bi];
               zzH[bi]=0;
               ai=i;
               tai=Time[i];
            }
            else if (countBarl>countBarh && countBarl>countBarExt && countBarl>minBars)
            {
               lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0;
               fs=2;countBarl=0;countBarh=0;countBarExt=0;
               zz[ai]=High[ai];
               zzH[ai]=High[ai];
               zzL[ai]=0;
               bi=i;
               tbi=Time[i];
            }
         }
         else
         {
            if (lLast_m==0 && hLast_m==0)
            {
               countBarl=0;countBarh=0;countBarExt=0;
            }

            if (fs==1)
            {
               if (countBarl>countBarh && countBarl>countBarExt && countBarl>minBars)
               {
                  ai=iBarShift(Symbol(),Period(),tai); 
                  fs=2;
                  countBarl=0;

                  zz[ai]=High[ai];
                  zzH[ai]=High[ai];
                  zzL[ai]=0;
                  bi=i;
                  if (ExtLabel>0)
                  {
                     ha[ai]=High[ai]; la[ai]=0;
                     tml=Time[i]; ha[i]=0; la[i]=Low[i];
                  }
                  tbi=Time[i];

                  lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0;

                  for (n=0;countBarExt<minBars;n++) 
                  {
                     if (lLast<Low[i+n+1] && hLast>High[i+n+1]) {countBarExt++; countBarh++; lLast=Low[i+n+1]; hLast=High[i+n+1]; hLast_m=High[i];}
                     else break;
                  }

                  lLast=Low[i]; hLast=High[i];
               }
            }

            if (fs==2)
            {
               if (countBarh>countBarl && countBarh>countBarExt && countBarh>minBars)
               {
                  bi=iBarShift(Symbol(),Period(),tbi);
                  fs=1;
                  countBarh=0;

                  zz[bi]=Low[bi];
                  zzL[bi]=Low[bi];
                  zzH[bi]=0;
                  ai=i;
                  if (ExtLabel>0)
                  {
                     ha[bi]=0; la[bi]=Low[bi];
                     tmh=Time[i]; ha[i]=High[i]; la[i]=0;
                  }
                  tai=Time[i];

                  lLast=Low[i]; hLast=High[i]; lLast_m=0; hLast_m=0;

                  for (n=0;countBarExt<minBars;n++) 
                  {
                     if (lLast<Low[i+n+1] && hLast>High[i+n+1]) {countBarExt++; countBarl++; lLast=Low[i+n+1]; hLast=High[i+n+1]; lLast_m=Low[i];}
                     else break;
                  }

                  lLast=Low[i]; hLast=High[i];
               }
            }
         } 
      } 
      if (i==0)
      {
         if (hLast<High[i] && fs==1)
         {
            ai=i; tai=Time[i]; zz[ai]=High[ai]; zzH[ai]=High[ai]; zzL[ai]=0;
            if (ExtLabel>0) {ha[ai]=High[ai]; la[ai]=0;}
         }
         else if (lLast>Low[i] && fs==2)
         {
            bi=i; tbi=Time[i]; zz[bi]=Low[bi]; zzL[bi]=Low[bi]; zzH[bi]=0;
            if (ExtLabel>0) {la[bi]=Low[bi]; ha[bi]=0;}
         }

         ai0=iBarShift(Symbol(),Period(),tai); 
         bi0=iBarShift(Symbol(),Period(),tbi);

         if (bi0>1) if (fs==1)
         {
            for (n=bi0-1; n>=0; n--) {zzH[n]=0.0; zz[n]=0.0; if (ExtLabel>0) ha[n]=0;}
            zz[ai0]=High[ai0]; zzH[ai0]=High[ai0]; zzL[ai0]=0.0; if (ExtLabel>0) ha[ai0]=High[ai0];
         }
         if (ai0>1) if (fs==2)
         {
            for (n=ai0-1; n>=0; n--) {zzL[n]=0.0; zz[n]=0.0; if (ExtLabel>0) la[n]=0;} 
            zz[bi0]=Low[bi0]; zzL[bi0]=Low[bi0]; zzH[bi0]=0.0; if (ExtLabel>0) la[bi0]=Low[bi0];
         }

         if (ExtLabel>0)
         {
            if (fs==1) {aim=iBarShift(Symbol(),0,tmh); if (aim<bi0) ha[aim]=High[aim];}
            else if (fs==2) {bim=iBarShift(Symbol(),0,tml); if (bim<ai0) la[bim]=Low[bim];}
         }

         if (ti<Time[1]) i=2;
      }
   }
}

//+------------------------------------------------------------------+
//| 高低点获取函数                                                    |
//+------------------------------------------------------------------+

// 获取指定范围内的最高点
void GetHigh(int start, int end, double price, int step)
{
   if(start < 0 || end >= Bars || start >= end) return;
   
   int highestBar = start;
   double highestPrice = High[start];
   
   for(int i = start; i <= end; i += step)
   {
      if(High[i] > highestPrice)
      {
         highestPrice = High[i];
         highestBar = i;
      }
   }
   
   // 设置结果（可通过引用参数返回）
   // 这里简化处理，实际应该有输出参数
}

// 获取指定范围内的最低点
void GetLow(int start, int end, double price, int step)
{
   if(start < 0 || end >= Bars || start >= end) return;
   
   int lowestBar = start;
   double lowestPrice = Low[start];
   
   for(int i = start; i <= end; i += step)
   {
      if(Low[i] < lowestPrice)
      {
         lowestPrice = Low[i];
         lowestBar = i;
      }
   }
   
   // 设置结果（可通过引用参数返回）
   // 这里简化处理，实际应该有输出参数
}

//+------------------------------------------------------------------+
//| 模块工具函数                                                      |
//+------------------------------------------------------------------+

// ZigZag数据验证
bool ValidateZigZagData()
{
   int zigzagPoints = 0;
   for(int i = 0; i < Bars; i++)
   {
      if(zz[i] != 0) zigzagPoints++;
   }
   
   return(zigzagPoints >= 3); // 至少需要3个ZigZag点
}

// ZigZag点计数
int CountZigZagPoints()
{
   int count = 0;
   for(int i = 0; i < Bars; i++)
   {
      if(zz[i] != 0) count++;
   }
   return(count);
}

// 获取最近的ZigZag点
double GetLastZigZagPoint(int& index)
{
   for(int i = 0; i < Bars; i++)
   {
      if(zz[i] != 0)
      {
         index = i;
         return(zz[i]);
      }
   }
   index = -1;
   return(0);
}

//+------------------------------------------------------------------+
//| 模块信息函数                                                      |
//+------------------------------------------------------------------+

// 获取模块信息
string GetZigZagModuleInfo()
{
   return("ZigZag指标模块 v1.00 - 提供多种ZigZag算法和峰值识别");
}

//+------------------------------------------------------------------+
//| 高级ZigZag算法扩展 (来自04-ZigZag指标模块)                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ZigZag算法类型枚举                                               |
//+------------------------------------------------------------------+
enum ZIGZAG_TYPE {
    ZIGZAG_STANDARD = 0,    // 标准ZigZag
    ZIGZAG_NONLAG = 1,      // 无滞后ZigZag
    ZIGZAG_SQZZ = 2,        // SQZZ算法
    ZIGZAG_TALEX = 3,       // Talex算法
    ZIGZAG_TAUBER = 4,      // Tauber算法
    ZIGZAG_WELLX = 5,       // Wellx算法
    ZIGZAG_PERCENT = 6      // 百分比ZigZag
};

//+------------------------------------------------------------------+
//| ZigZag数据结构                                                   |
//+------------------------------------------------------------------+
struct ZigZagPoint {
    double price;           // 价格
    datetime time;          // 时间
    int bar_index;          // K线索引
    bool is_high;           // 是否为高点
};

//+------------------------------------------------------------------+
//| ZigZag参数结构                                                   |
//+------------------------------------------------------------------+
struct ZigZagParameters {
    int depth;              // 深度
    int deviation;          // 偏差
    int backstep;           // 回溯
    int minBars;            // 最小K线数
    int minSize;            // 最小尺寸
    double minPercent;      // 最小百分比
    int maxBar;             // 最大K线
    int minBar;             // 最小K线
};

//+------------------------------------------------------------------+
//| 全局ZigZag数据数组扩展                                           |
//+------------------------------------------------------------------+
double g_zz_advanced[];         // 高级ZigZag数组
double g_zzH_advanced[];        // 高级高点数组
double g_zzL_advanced[];        // 高级低点数组
double g_ha_advanced[];         // 高级高点辅助数组
double g_la_advanced[];         // 高级低点辅助数组

//+------------------------------------------------------------------+
//| 高级ZigZag数组初始化                                             |
//+------------------------------------------------------------------+
void InitializeAdvancedZigZagArrays(int bars)
{
    ArrayResize(g_zz_advanced, bars);
    ArrayResize(g_zzH_advanced, bars);
    ArrayResize(g_zzL_advanced, bars);
    ArrayResize(g_ha_advanced, bars);
    ArrayResize(g_la_advanced, bars);
    
    ArrayInitialize(g_zz_advanced, 0.0);
    ArrayInitialize(g_zzH_advanced, 0.0);
    ArrayInitialize(g_zzL_advanced, 0.0);
    ArrayInitialize(g_ha_advanced, 0.0);
    ArrayInitialize(g_la_advanced, 0.0);
}

//+------------------------------------------------------------------+
//| 标准ZigZag算法（增强版）                                         |
//+------------------------------------------------------------------+
void CalculateStandardZigZag(ZigZagParameters& params)
{
    int shift, back, lasthighpos, lastlowpos;
    double val, res;
    double curlow, curhigh, lasthigh, lastlow;
    
    int maxbar = (params.maxBar > 0) ? params.maxBar : Bars;
    
    // 清零数组
    for(int i = 0; i < maxbar; i++)
    {
        g_zz_advanced[i] = 0.0;
        g_zzH_advanced[i] = 0.0;
        g_zzL_advanced[i] = 0.0;
    }
    
    // 寻找低点
    for(shift = maxbar - params.depth; shift >= 0; shift--)
    {
        val = Low[iLowest(Symbol(), 0, MODE_LOW, params.depth * 2 + 1, shift)];
        if(val == Low[shift])
            g_zzL_advanced[shift] = val;
        else
            g_zzL_advanced[shift] = 0.0;
            
        // 清除相近的低点
        if(g_zzL_advanced[shift] != 0.0)
        {
            for(back = 1; back <= params.backstep; back++)
            {
                res = g_zzL_advanced[shift + back];
                if((res != 0) && (res > val))
                    g_zzL_advanced[shift + back] = 0.0;
            }
        }
    }
    
    // 寻找高点
    for(shift = maxbar - params.depth; shift >= 0; shift--)
    {
        val = High[iHighest(Symbol(), 0, MODE_HIGH, params.depth * 2 + 1, shift)];
        if(val == High[shift])
            g_zzH_advanced[shift] = val;
        else
            g_zzH_advanced[shift] = 0.0;
            
        // 清除相近的高点
        if(g_zzH_advanced[shift] != 0.0)
        {
            for(back = 1; back <= params.backstep; back++)
            {
                res = g_zzH_advanced[shift + back];
                if((res != 0) && (res < val))
                    g_zzH_advanced[shift + back] = 0.0;
            }
        }
    }
    
    // 合并高低点到主数组
    lasthigh = -1; lasthighpos = -1;
    lastlow = -1; lastlowpos = -1;
    
    for(shift = maxbar - 1; shift >= 0; shift--)
    {
        curlow = g_zzL_advanced[shift];
        curhigh = g_zzH_advanced[shift];
        
        if((curlow == 0) && (curhigh == 0))
            continue;
            
        if(curhigh != 0)
        {
            if(lasthigh > 0)
            {
                if(lasthigh < curhigh)
                    g_zzH_advanced[lasthighpos] = 0;
                else
                    g_zzH_advanced[shift] = 0;
            }
            if(g_zzH_advanced[shift] != 0)
            {
                lasthigh = curhigh;
                lasthighpos = shift;
            }
            lastlow = -1;
        }
        
        if(curlow != 0)
        {
            if(lastlow > 0)
            {
                if(lastlow > curlow)
                    g_zzL_advanced[lastlowpos] = 0;
                else
                    g_zzL_advanced[shift] = 0;
            }
            if(g_zzL_advanced[shift] != 0)
            {
                lastlow = curlow;
                lastlowpos = shift;
            }
            lasthigh = -1;
        }
    }
    
    // 填充主ZigZag数组
    for(shift = maxbar - 1; shift >= 0; shift--)
    {
        if(g_zzL_advanced[shift] != 0)
            g_zz_advanced[shift] = g_zzL_advanced[shift];
        else if(g_zzH_advanced[shift] != 0)
            g_zz_advanced[shift] = g_zzH_advanced[shift];
        else
            g_zz_advanced[shift] = 0.0;
    }
}

//+------------------------------------------------------------------+
//| SQZZ ZigZag算法（高性能版本）                                    |
//+------------------------------------------------------------------+
void CalculateSQZZ(ZigZagParameters& params, bool zzFill = true)
{
    static int act_time = 0;
    static int H1 = 10000, L1 = 10000, H2 = 10000, H3 = 10000;
    static int L2 = 10000, L3 = 10000;
    static double H1p = -1, H2p = -1, H3p = -1;
    static double L1p = 10000, L2p = 10000, L3p = 10000;
    
    int counted_bars = IndicatorCounted();
    int limit = Bars - counted_bars;
    
    if(counted_bars > 0) limit++;
    
    for(int i = limit; i >= 0; i--)
    {
        // SQZZ算法核心逻辑
        g_zz_advanced[i] = 0.0;
        g_zzH_advanced[i] = 0.0;
        g_zzL_advanced[i] = 0.0;
        
        // 高点检测
        bool isHigh = true;
        for(int j = 1; j <= params.depth && i + j < Bars; j++)
        {
            if(High[i] <= High[i + j])
            {
                isHigh = false;
                break;
            }
        }
        for(int j = 1; j <= params.depth && i - j >= 0; j++)
        {
            if(High[i] <= High[i - j])
            {
                isHigh = false;
                break;
            }
        }
        
        // 低点检测
        bool isLow = true;
        for(int j = 1; j <= params.depth && i + j < Bars; j++)
        {
            if(Low[i] >= Low[i + j])
            {
                isLow = false;
                break;
            }
        }
        for(int j = 1; j <= params.depth && i - j >= 0; j++)
        {
            if(Low[i] >= Low[i - j])
            {
                isLow = false;
                break;
            }
        }
        
        // 设置ZigZag值
        if(isHigh && !isLow)
        {
            g_zzH_advanced[i] = High[i];
            g_zz_advanced[i] = High[i];
        }
        else if(isLow && !isHigh)
        {
            g_zzL_advanced[i] = Low[i];
            g_zz_advanced[i] = Low[i];
        }
    }
}

//+------------------------------------------------------------------+
//| Talex ZigZag算法                                                 |
//+------------------------------------------------------------------+
void CalculateTalexZigZag(int n)
{
    for(int i = Bars - n - 1; i >= n; i--)
    {
        // Talex算法实现
        double sumHigh = 0, sumLow = 0;
        double avgHigh, avgLow;
        
        // 计算平均值
        for(int j = 0; j < n; j++)
        {
            sumHigh += High[i + j];
            sumLow += Low[i + j];
        }
        
        avgHigh = sumHigh / n;
        avgLow = sumLow / n;
        
        // 确定ZigZag点
        if(High[i] > avgHigh * 1.01) // 1%阈值
        {
            g_zzH_advanced[i] = High[i];
            g_zz_advanced[i] = High[i];
        }
        else if(Low[i] < avgLow * 0.99) // 1%阈值
        {
            g_zzL_advanced[i] = Low[i];
            g_zz_advanced[i] = Low[i];
        }
        else
        {
            g_zzH_advanced[i] = 0;
            g_zzL_advanced[i] = 0;
            g_zz_advanced[i] = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| Tauber ZigZag算法                                                |
//+------------------------------------------------------------------+
void CalculateTauberZigZag(ZigZagParameters& params)
{
    double threshold = params.minPercent / 100.0;
    
    for(int i = Bars - params.depth; i >= 0; i--)
    {
        g_zz_advanced[i] = 0.0;
        g_zzH_advanced[i] = 0.0;
        g_zzL_advanced[i] = 0.0;
        
        // 寻找显著的高点
        bool isSignificantHigh = true;
        for(int j = 1; j <= params.depth; j++)
        {
            if(i + j < Bars)
            {
                if(High[i] < High[i + j] * (1 + threshold))
                {
                    isSignificantHigh = false;
                    break;
                }
            }
            if(i - j >= 0)
            {
                if(High[i] < High[i - j] * (1 + threshold))
                {
                    isSignificantHigh = false;
                    break;
                }
            }
        }
        
        // 寻找显著的低点
        bool isSignificantLow = true;
        for(int j = 1; j <= params.depth; j++)
        {
            if(i + j < Bars)
            {
                if(Low[i] > Low[i + j] * (1 - threshold))
                {
                    isSignificantLow = false;
                    break;
                }
            }
            if(i - j >= 0)
            {
                if(Low[i] > Low[i - j] * (1 - threshold))
                {
                    isSignificantLow = false;
                    break;
                }
            }
        }
        
        // 设置ZigZag值
        if(isSignificantHigh)
        {
            g_zzH_advanced[i] = High[i];
            g_zz_advanced[i] = High[i];
        }
        if(isSignificantLow)
        {
            g_zzL_advanced[i] = Low[i];
            g_zz_advanced[i] = Low[i];
        }
    }
}

//+------------------------------------------------------------------+
//| 统一ZigZag计算接口                                               |
//+------------------------------------------------------------------+
void CalculateZigZag(ZIGZAG_TYPE type, ZigZagParameters& params)
{
    switch(type)
    {
        case ZIGZAG_STANDARD:
            CalculateStandardZigZag(params);
            break;
        case ZIGZAG_SQZZ:
            CalculateSQZZ(params);
            break;
        case ZIGZAG_TALEX:
            CalculateTalexZigZag(params.depth);
            break;
        case ZIGZAG_TAUBER:
            CalculateTauberZigZag(params);
            break;
        default:
            CalculateStandardZigZag(params);
            break;
    }
}

//+------------------------------------------------------------------+
//| ZigZag数据访问函数                                               |
//+------------------------------------------------------------------+

// 获取最近的ZigZag点
int GetRecentZigZagPoints(ZigZagPoint& points[], int maxPoints = 10)
{
    int count = 0;
    ArrayResize(points, maxPoints);
    
    for(int i = 0; i < Bars && count < maxPoints; i++)
    {
        if(g_zz_advanced[i] != 0)
        {
            points[count].price = g_zz_advanced[i];
            points[count].time = Time[i];
            points[count].bar_index = i;
            points[count].is_high = (g_zzH_advanced[i] != 0);
            count++;
        }
    }
    
    return count;
}

// 验证ZigZag数据
bool ValidateZigZagData()
{
    int validPoints = 0;
    for(int i = 0; i < ArraySize(g_zz_advanced); i++)
    {
        if(g_zz_advanced[i] != 0)
            validPoints++;
    }
    
    Print("ZigZag验证完成，有效点数：", validPoints);
    return validPoints > 0;
}

// 获取ZigZag值的访问函数
double GetAdvancedZZ(int index) 
{ 
    return (index >= 0 && index < ArraySize(g_zz_advanced)) ? g_zz_advanced[index] : 0.0; 
}

double GetAdvancedZZH(int index) 
{ 
    return (index >= 0 && index < ArraySize(g_zzH_advanced)) ? g_zzH_advanced[index] : 0.0; 
}

double GetAdvancedZZL(int index) 
{ 
    return (index >= 0 && index < ArraySize(g_zzL_advanced)) ? g_zzL_advanced[index] : 0.0; 
}

//+------------------------------------------------------------------+
//| ZigZag算法名称获取                                               |
//+------------------------------------------------------------------+
string GetZigZagTypeName(ZIGZAG_TYPE type)
{
    switch(type)
    {
        case ZIGZAG_STANDARD: return "标准ZigZag";
        case ZIGZAG_NONLAG:   return "无滞后ZigZag";
        case ZIGZAG_SQZZ:     return "SQZZ算法";
        case ZIGZAG_TALEX:    return "Talex算法";
        case ZIGZAG_TAUBER:   return "Tauber算法";
        case ZIGZAG_WELLX:    return "Wellx算法";
        case ZIGZAG_PERCENT:  return "百分比ZigZag";
        default:              return "未知算法";
    }
}

//+------------------------------------------------------------------+
//| ZigZag性能测试                                                   |
//+------------------------------------------------------------------+
void TestZigZagPerformance()
{
    int startTime = GetTickCount();
    
    ZigZagParameters testParams;
    testParams.depth = 12;
    testParams.deviation = 5;
    testParams.backstep = 3;
    testParams.maxBar = 1000;
    
    CalculateZigZag(ZIGZAG_STANDARD, testParams);
    
    int endTime = GetTickCount();
    Print("ZigZag性能测试完成，耗时：", endTime - startTime, "毫秒");
} 

//+------------------------------------------------------------------+
//| Tauber算法辅助函数                                               |
//+------------------------------------------------------------------+

/**
 * GetHigh函数 - Tauber算法辅助函数
 * 功能：递归查找高点
 */
void GetHigh(int start, int end, double price, int step)
{
   int count=end-start;
   if (count<=0) return;
   int i=iHighest(NULL,0,MODE_HIGH,count+1,start);
   double val=High[i];
   if ((val-price)>(minSize*Point))
   { 
      zzH[i]=val;
      if (i==start) {GetLow(start+step,end-step,val,1-step); if (start-1>=0 && zzL[start-1]>0) zzL[start]=0; return;}     
      if (i==end) {GetLow(start+step,end-step,val,1-step); if (end+1<Bars && zzL[end+1]>0) zzL[end]=0; return;} 
      GetLow(start,i-1,val,0);
      GetLow(i+1,end,val,0);
   }
}

/**
 * GetLow函数 - Tauber算法辅助函数
 * 功能：递归查找低点
 */
void GetLow(int start, int end, double price, int step)
{
   int count=end-start;
   if (count<=0) return;
   int i=iLowest(NULL,0,MODE_LOW,count+1,start);
   double val=Low[i];
   if ((price-val)>(minSize*Point))
   {
      zzL[i]=val; 
      if (i==start) {GetHigh(start+step,end-step,val,1-step); if (start-1>=0 && zzH[start-1]>0) zzH[start]=0; return;}     
      if (i==end) {GetHigh(start+step,end-step,val,1-step); if (end+1<Bars && zzH[end+1]>0) zzH[end]=0; return;}   
      GetHigh(start,i-1,val,0);
      GetHigh(i+1,end,val,0);
   }
}