#!/usr/bin/env python3

from optparse import OptionParser
import logging
import sys
import time
import math
import smbus
import os

EMC2301_ADDRESS        =        (0X2F)
TACHO_FREQUENCY        =         32768
EDGES                  =           5

EMC2301_PWMBASEFREQ    =        (0x2D)
EMC2301_FANSETTING     =        (0x30)
EMC2301_PWMDIVIDE      =        (0x31)
EMC2301_FANCONFIG1     =        (0x32)
EMC2301_FANCONFIG2     =        (0x33)
EMC2301_FANSPINUP      =        (0x36)
EMC2301_FANMAXSTEP     =        (0x37)
EMC2301_FANMINDRIVE      =      (0x38)
EMC2301_FANVALTACHCOUNT  =      (0x39)
EMC2301_TACHTARGETLSB    =      (0x3C)
EMC2301_TACHTARGETMSB    =      (0x3D)
EMC2301_TACHREADMSB      =      (0x3E)
EMC2301_TACHREADLSB      =      (0x3F)
PRODUCT_ID               =      (0xFD)
MANUFACTURER_ID          =      (0xFE)

#PWM base freq
EMC2301_PWMBASEFREQ_26KHZ   = 0x00
EMC2301_PWMBASEFREQ_19KHZ   = 0x01
EMC2301_PWMBASEFREQ_4KHZ    = 0x02
EMC2301_PWMBASEFREQ_2KHZ    = 0x03

# EMC2301_FANCONFIG1
EMC2301_FANCONFIG1_RPMCONTROL     = 0x80
EMC2301_FANCONFIG1_MINRPM_CLEAR   =   (~0x60)
EMC2301_FANCONFIG1_MINRPM_500     = 0x00
EMC2301_FANCONFIG1_MINRPM_1000    = 0x20
EMC2301_FANCONFIG1_MINRPM_2000    = 0x40
EMC2301_FANCONFIG1_MINRPM_4000    = 0x60
EMC2301_FANCONFIG1_FANPOLES_CLEAR =   (~0x18)
EMC2301_FANCONFIG1_FANPOLES_1     = 0x00
EMC2301_FANCONFIG1_FANPOLES_2     = 0x08
EMC2301_FANCONFIG1_FANPOLES_3     = 0x10
EMC2301_FANCONFIG1_FANPOLES_4     = 0x18
EMC2301_FANCONFIG1_UPDATE_CLEAR  =    (~0x07)
EMC2301_FANCONFIG1_UPDATE_100     = 0x00
EMC2301_FANCONFIG1_UPDATE_200     = 0x01
EMC2301_FANCONFIG1_UPDATE_300     = 0x02
EMC2301_FANCONFIG1_UPDATE_400     = 0x03
EMC2301_FANCONFIG1_UPDATE_500     = 0x04
EMC2301_FANCONFIG1_UPDATE_800     = 0x05
EMC2301_FANCONFIG1_UPDATE_1200    = 0x06
EMC2301_FANCONFIG1_UPDATE_1600    = 0x07

# EMC2301_FANCONFIG2
EMC2301_FANCONFIG2_RAMPCONTROL    = 0x40
EMC2301_FANCONFIG2_GLITCHFILTER   = 0x20
EMC2301_FANCONFIG2_DEROPT_CLEAR   =   (~0x18)
EMC2301_FANCONFIG2_DEROPT_NONE    = 0x00
EMC2301_FANCONFIG2_DEROPT_BASIC   = 0x08
EMC2301_FANCONFIG2_DEROPT_STEP    = 0x10
EMC2301_FANCONFIG2_DEROPT_BOTH    = 0x18
EMC2301_FANCONFIG2_ERRRANGE_CLEAR =   (~0x06)
EMC2301_FANCONFIG2_ERRRANGE_0     = 0x00
EMC2301_FANCONFIG2_ERRRANGE_50    = 0x02
EMC2301_FANCONFIG2_ERRRANGE_100   = 0x04
EMC2301_FANCONFIG2_ERRRANGE_200   = 0x06

# EMC2301_FANSPINUP
EMC2301_FANSPINUP_NOKICK          =  0x20
EMC2301_FANSPINUP_SPINLVL_CLEAR   =     (~0x1C)
EMC2301_FANSPINUP_SPINLVL_30      =   0x00
EMC2301_FANSPINUP_SPINLVL_35      =   0x04
EMC2301_FANSPINUP_SPINLVL_40      =   0x08
EMC2301_FANSPINUP_SPINLVL_45      =    0x0C
EMC2301_FANSPINUP_SPINLVL_50      =   0x10
EMC2301_FANSPINUP_SPINLVL_55      =   0x14
EMC2301_FANSPINUP_SPINLVL_60      =   0x18
EMC2301_FANSPINUP_SPINLVL_65      =   0x1C
EMC2301_FANSPINUP_SPINUPTIME_CLEAR  =   (~0x03)
EMC2301_FANSPINUP_SPINUPTIME_250   =  0x00
EMC2301_FANSPINUP_SPINUPTIME_500   =  0x01
EMC2301_FANSPINUP_SPINUPTIME_1000  =  0x02
EMC2301_FANSPINUP_SPINUPTIME_2000  =  0x03
  
# EMC2301_REG_FANMAXSTEP
EMC2301_FANMAXSTEP_MAX          =    0b00111111 

TachoRead_Hb = [32,64,128,256,512,1024,2048,4096] 
TachoRead_Lb = [0,0,0,1,2,4,8,16] 
TachoTar_Hb  = [4096,2048,1024,512,256,128,64,32] 
TachoTar_Lb  = [16,8,4,2,1] 
TachoTar_Sum  =  [128,64,32,16,8,4,2,1] 

MIN_RPM_MULTIPLIER   = 2
MULTIPLIER           = 1
POLES      = 2
class EMC2301:
    def __init__(self, address=EMC2301_ADDRESS, busnum=10):
        self.i2c = smbus.SMBus(busnum)
        self.address = address

        
    def Read_Byte(self, Addr):
        return self.i2c.read_byte_data(self.address, Addr)
        
    def Write_Byte(self, Addr, val):
        self.i2c.write_byte_data(self.address, Addr, val )
        
    def EMC2301_WriteRegconfig_Byte(self,Addr,Configvalue,Value):
        data = self.Read_Byte(Addr)
        data &= Configvalue
        data |= Value
        self.Write_Byte(Addr,data)
        
        
    def EMC2301_RPMEnable(self):   
        self.Write_Byte(EMC2301_FANCONFIG2, 0x40)
        self.Write_Byte(EMC2301_FANCONFIG1, 0x80)
        
    #------------------------------
    def EMC2301_setPWMFrequencyBase(self,frequencyKHz):
        writeByte = 0
        if (frequencyKHz < 4.882):
            writeByte = EMC2301_PWMBASEFREQ_2KHZ 
        elif (frequencyKHz < 19.531):
            writeByte = EMC2301_PWMBASEFREQ_4KHZ 
        elif (frequencyKHz < 26):
            writeByte = EMC2301_PWMBASEFREQ_19KHZ 
        else:
            writeByte = EMC2301_PWMBASEFREQ_26KHZ 
        self.Write_Byte(EMC2301_PWMBASEFREQ,writeByte) 

    def EMC2301_toggleControlAlgorithm(self, enable):
        if (enable == true):
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG1, ~EMC2301_FANCONFIG1_RPMCONTROL, EMC2301_FANCONFIG1_RPMCONTROL) 
        else:
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG1, ~EMC2301_FANCONFIG1_RPMCONTROL, 0)


    def EMC2301_setTachMinRPM(self, minRPM): 
        writeByte = 0 
        if (minRPM < 1000):
            writeByte = EMC2301_FANCONFIG1_MINRPM_500 
            MIN_RPM_MULTIPLIER = 1 
        elif (minRPM < 2000):
            writeByte = EMC2301_FANCONFIG1_MINRPM_1000 
            MIN_RPM_MULTIPLIER = 2 
        elif (minRPM < 4000):
            writeByte = EMC2301_FANCONFIG1_MINRPM_2000 
            MIN_RPM_MULTIPLIER = 4 
        else:
            writeByte = EMC2301_FANCONFIG1_MINRPM_4000 
            MIN_RPM_MULTIPLIER = 8 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG1, EMC2301_FANCONFIG1_MINRPM_CLEAR, writeByte) 
 

    def EMC2301_setFanPoles(self,poleCount):
        writeByte = 0 
        if(poleCount==1):
            writeByte = EMC2301_FANCONFIG1_FANPOLES_1 
            MULTIPLIER = 1 
        elif(poleCount==2):
            writeByte = EMC2301_FANCONFIG1_FANPOLES_2 
            MULTIPLIER = 2 
        elif(poleCount==3):
            writeByte = EMC2301_FANCONFIG1_FANPOLES_3 
            MULTIPLIER = 3 
        elif(poleCount==4):
            writeByte = EMC2301_FANCONFIG1_FANPOLES_4 
            MULTIPLIER = 4 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG1, EMC2301_FANCONFIG1_FANPOLES_CLEAR, writeByte) 

    def EMC2301_setDriveUpdatePeriod(self,periodMs):
        writeByte = 0 
        if (periodMs < 200):
            writeByte = EMC2301_FANCONFIG1_UPDATE_100 
        elif (periodMs < 300):
            writeByte = EMC2301_FANCONFIG1_UPDATE_200 
        elif (periodMs < 400):
            writeByte = EMC2301_FANCONFIG1_UPDATE_300 
        elif (periodMs < 500):
            writeByte = EMC2301_FANCONFIG1_UPDATE_400 
        elif (periodMs < 800):
            writeByte = EMC2301_FANCONFIG1_UPDATE_500 
        elif (periodMs < 1200):
            writeByte = EMC2301_FANCONFIG1_UPDATE_800 
        elif (periodMs < 1600):
            writeByte = EMC2301_FANCONFIG1_UPDATE_1200 
        else:
            writeByte = EMC2301_FANCONFIG1_UPDATE_1600 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG1, EMC2301_FANCONFIG1_UPDATE_CLEAR, writeByte) 
 

    def EMC2301_toggleRampControl(self,enable):
        if (enable == true):
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, ~EMC2301_FANCONFIG2_RAMPCONTROL, EMC2301_FANCONFIG2_RAMPCONTROL) 
        else:
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, ~EMC2301_FANCONFIG2_RAMPCONTROL, 0) 

    def EMC2301_toggleGlitchFilter(self,enable):
        if (enable == true):
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, ~EMC2301_FANCONFIG2_GLITCHFILTER, EMC2301_FANCONFIG2_GLITCHFILTER) 
        else:
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, ~EMC2301_FANCONFIG2_GLITCHFILTER, 0) 


    def EMC2301_setDerivativeMode(self,modeType):
        writeByte = 0 
        if(modeType == 0):
            writeByte = EMC2301_FANCONFIG2_DEROPT_NONE 
        elif(modeType == 1):
            writeByte = EMC2301_FANCONFIG2_DEROPT_BASIC 
        elif(modeType == 2):
            writeByte = EMC2301_FANCONFIG2_DEROPT_STEP 
        elif(modeType == 3):
            writeByte = EMC2301_FANCONFIG2_DEROPT_BOTH 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, EMC2301_FANCONFIG2_DEROPT_CLEAR, writeByte) 


    def EMC2301_setControlErrRange(self,errorRangeRPM):
        writeByte = 0
        if (errorRangeRPM < 0.01): 
            writeByte = EMC2301_FANCONFIG2_ERRRANGE_0 
        elif (errorRangeRPM <= 50):
            writeByte = EMC2301_FANCONFIG2_ERRRANGE_50 
        elif (errorRangeRPM <= 100):
            writeByte = EMC2301_FANCONFIG2_ERRRANGE_100 
        else:
            writeByte = EMC2301_FANCONFIG2_ERRRANGE_200 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANCONFIG2, EMC2301_FANCONFIG2_ERRRANGE_CLEAR, writeByte) 
   
    def EMC2301_toggleSpinUpMax(self,enable):
        if (enable == true):
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANSPINUP, ~EMC2301_FANSPINUP_NOKICK, EMC2301_FANSPINUP_NOKICK) 
        else:
            self.EMC2301_WriteRegconfig_Byte(EMC2301_FANSPINUP, ~EMC2301_FANSPINUP_NOKICK, 0) 


    def EMC2301_setSpinUpDrive(self,drivePercent):
        writeByte  = 0 
        if (drivePercent < 35):
            writeByte = EMC2301_FANSPINUP_SPINLVL_30 
        elif (drivePercent < 40):
            writeByte = EMC2301_FANSPINUP_SPINLVL_35 
        elif (drivePercent < 45):
            writeByte = EMC2301_FANSPINUP_SPINLVL_40 
        elif (drivePercent < 50):
            writeByte = EMC2301_FANSPINUP_SPINLVL_45 
        elif (drivePercent < 55):
            writeByte = EMC2301_FANSPINUP_SPINLVL_50 
        elif (drivePercent < 60):
            writeByte = EMC2301_FANSPINUP_SPINLVL_55 
        elif (drivePercent < 65):
            writeByte = EMC2301_FANSPINUP_SPINLVL_60 
        else:
            writeByte = EMC2301_FANSPINUP_SPINLVL_65 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANSPINUP, EMC2301_FANSPINUP_SPINLVL_CLEAR, writeByte) 

    def EMC2301_setSpinUpTime(self,timeMs): 
        writeByte = 0 
        if (timeMs < 500):
            writeByte = EMC2301_FANSPINUP_SPINUPTIME_250 
        elif (timeMs < 1000):
            writeByte = EMC2301_FANSPINUP_SPINUPTIME_500 
        elif (timeMs < 2000):
            writeByte = EMC2301_FANSPINUP_SPINUPTIME_1000 
        else:
            writeByte = EMC2301_FANSPINUP_SPINUPTIME_2000 
            writeByte = EMC2301_FANSPINUP_SPINUPTIME_2000 
        self.EMC2301_WriteRegconfig_Byte(EMC2301_FANSPINUP, EMC2301_FANSPINUP_SPINUPTIME_CLEAR, writeByte) 
    
    def EMC2301_setControlMaxStep(self,stepSize):
        if (stepSize > EMC2301_FANMAXSTEP_MAX):
            stepSize = EMC2301_FANMAXSTEP_MAX 
            self.Write_Byte(EMC2301_FANMAXSTEP, stepSize) 
  
    def EMC2301_setFanMinDrive(self,minDrivePercent):
        writeByte = 0
        writeByte = (uint8_t)( 50/ 100 * 255) 
        self.Write_Byte(EMC2301_FANMINDRIVE, writeByte) 


    def EMC2301_setMinValidRPM(self,minRPM):
        tachMinRPM = 0 
        if(MIN_RPM_MULTIPLIER == 1):
            tachMinRPM = 500 
        elif(MIN_RPM_MULTIPLIER == 2):
            tachMinRPM = 1000 
        elif(MIN_RPM_MULTIPLIER == 3):
            tachMinRPM = 2000 
        elif(MIN_RPM_MULTIPLIER == 4):
            tachMinRPM = 4000        
        if (minRPM < tachMinRPM):
            minRPM = tachMinRPM 
        maxTachCount_ = 0   
        maxTachCount_ = 60 * MIN_RPM_MULTIPLIER * TACHO_FREQUENCY * (MULTIPLIER - 2) / 2 / POLES / minRPM 
        self.Write_Byte(EMC2301_FANVALTACHCOUNT, maxTachCount_) 


    #------------------------------   
    def EMC2301_fetchFanSpeed(self):
        tachoCount_MSB = self.Read_Byte(EMC2301_TACHREADMSB)
        #print('MSB addr: %x\r\'%Res_value)
        Res_value = 0
        tachread_flag = 0x01
        for i in range(0,8):
            if(tachoCount_MSB&tachread_flag ):
                Res_value = Res_value+TachoRead_Hb [i]
            tachread_flag = tachread_flag<<1 		
        #print('MSB Res_value: %d\r\n'%Res_value)	
        tachoCount_LSB = self.Read_Byte(EMC2301_TACHREADLSB)	
        #print('LSB addr: 0x%x\r\n'%tachCountLSB)	
        tachread_flag = 0x01 
        for i in range(0,8):
            if(tachoCount_LSB&tachread_flag):
                Res_value = Res_value+TachoRead_Lb[i] 
            tachread_flag = tachread_flag<<1 
        print('End Res_value: %d\r\n'%Res_value)
        FAN_SPEED = ((EDGES-1)*MULTIPLIER*TACHO_FREQUENCY*60)/(POLES*Res_value) 
        print('FAN_SPEED: %d\r\n'%FAN_SPEED)
        print('---------------------\r\n')
        
    def EMC2301_writeTachoTarget(self,tachoTarget): 
        print('write tachoTarget: %d ------------>>>\r\n'%tachoTarget)
        tachCountLSB = 0 
        tachCountMSB = 0 

        if(tachoTarget<=31):		
            sum_xx = 0 
            temp_xx = tachoTarget 
            tachCountLSB = 0#---------- 
            for i in range(0,5):
                if(temp_xx >= TachoTar_Lb[i]):
                    sum_xx = sum_xx + TachoTar_Lb[i] 
                    tachCountLSB = tachCountLSB + TachoTar_Sum[i] 
                    temp_xx = tachoTarget - sum_xx
            print('tachCountLSB: 0x%x\r\n'%tachCountLSB)
            self.Write_Byte(EMC2301_TACHTARGETLSB, tachCountLSB) 
        else:
            sum = 0 
            temp = tachoTarget 
            tachCountMSB = 0 
            for i in range(0,8):
                if(temp >= TachoTar_Hb[i]):
                    sum = sum+TachoTar_Hb[i] 
                    tachCountMSB = tachCountMSB + TachoTar_Sum[i] 
                    temp = tachoTarget - sum 
		
            sum_xx = 0 
            temp_xx = tachoTarget 
            tachCountLSB = 0 
            for i in range(0,5):
                if(temp_xx >= TachoTar_Lb[i]):
                    sum_xx = sum_xx + TachoTar_Lb[i] 
                    tachCountLSB = tachCountLSB + TachoTar_Sum[i] 
                    temp_xx = tachoTarget - sum_xx 
            tachCountLSB = tachCountLSB 
            print('tachCountLSB: 0x%x\r\n'%tachCountLSB)
            print('tachCountMSB: 0x%x\r\n'%tachCountMSB)
            self.Write_Byte(EMC2301_TACHTARGETLSB, tachCountLSB) 
            self.Write_Byte(EMC2301_TACHTARGETMSB, tachCountMSB)      

        
    def EMC2301_Directspeedcontrol(self,value):
        self.Write_Byte(EMC2301_FANCONFIG2, 0x40) 
        self.Write_Byte(EMC2301_FANCONFIG1, 0x00)  
        self.Write_Byte(EMC2301_FANSETTING,value) 
        time.sleep(2)
        
usage = "./test_emc2301 [options] [value]"
parser = OptionParser(usage=usage)

parser.add_option("-a", "--address", type = "int", action="store", dest="address", default=0x2f, help="Address of the emc2301 in the bus (defaults to 0x2f)")
parser.add_option("-b", "--bus", type = "int", action="store", dest="bus", default=10, help="I2C channel (0 or 1,defaults to 1)")


(options, args) = parser.parse_args()

addr = options.address
bus = options.bus

if len(args) == 0:
    print("argument 'value' is mandatory")
    sys.exit()

value = int(args[0])

if value < 0 or value > 100:
	print("ERROR: Value out of range")
	sys.exit()       
 
logging.basicConfig(level=logging.INFO)

obj = EMC2301(address=addr, busnum=bus)

try:
    product_ID = obj.Read_Byte(PRODUCT_ID)
    Manufacturer_ID = obj.Read_Byte(MANUFACTURER_ID)
    print('ID_value : 0x%x\r\n'%product_ID)
    print('Manufacturer_ID : 0x%x\r\n'%Manufacturer_ID)
    if(product_ID == 0x37 and Manufacturer_ID==0x5D):
        print('I2C OK !\r\n')
        speed = int(value*2.55)
        obj.EMC2301_Directspeedcontrol(speed)
        time.sleep(0.5)   
        #obj.EMC2301_setSpinUpDrive(60)
        #obj.EMC2301_setSpinUpTime(300)#speed up time
        #obj.EMC2301_setDriveUpdatePeriod(100) 
        #if value == 0:
        #    obj.EMC2301_writeTachoTarget(8192)
        #elif value < 12.5:
        #    obj.EMC2301_writeTachoTarget(4096)
        #elif value < 25:
        #    obj.EMC2301_writeTachoTarget(2048)
        #elif value < 37.5:
        #    obj.EMC2301_writeTachoTarget(1024)  
        #elif value < 50:
        #    obj.EMC2301_writeTachoTarget(512)
        #elif value < 62.5:
        #    obj.EMC2301_writeTachoTarget(256)  
        #elif value < 75:
        #    obj.EMC2301_writeTachoTarget(128)  
        #elif value < 87.5:
        #    obj.EMC2301_writeTachoTarget(64)
        #elif value <= 100:
        #    obj.EMC2301_writeTachoTarget(32)
        #time.sleep(0.5)
        #obj.EMC2301_fetchFanSpeed()
    else:
        print('I2C Error !\r\n')

except KeyboardInterrupt:
    logging.info('ctrl + c:')
    exit()
	        
