;********************************************************************
; to run: ncl yyyy=2017 month=01 day=14 hour=06 inityyyy=2017 initmonth=01 initday=01 inithour=00  convert_precip_forMODE.ncl
; note: do not add extra spaces!
; initmonth etc is the date of forecast initialization
; yyyy, month, day, hour is valid time

;*****************************************************
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
;***************************************
 
begin

NPac       = (/19,48,196,252/)		; West WRF d01 region

;;;;; find day minus 1

   ym1 = yyyy
   mm1 = month
   dm1 = day-1
   if (dm1.lt.1) 
      if (month.eq.4) 
         mm1 = month-1
	 dm1 = 31
      end if
      if (month.eq.3) 
         mm1 = month-1
	 dm1 = 28
      end if
      if (month.eq.2) 
         mm1 = month-1
	 dm1 = 31
      end if
      if (month.eq.1) 
         mm1 = 12
	 dm1 = 31
	 ym1 = yyyy-1
      end if
      if (month.eq.12) 
         mm1 = month-1
	 dm1 = 30
      end if
      if (month.eq.11) 
         mm1 = month-1
	 dm1 = 31
      end if
   end if
   dminus1 = tostring(dm1)
   mminus1 = tostring(mm1)
   yminus1 = tostring(ym1)
   if (dm1.lt.10) 
      dminus1="0"+dminus1
   end if
   if (mm1.lt.10) 
      mminus1="0"+mminus1
   end if

;;;;;;  turn command line inputs into strings

   d = tostring(day)
   d2 = tostring(initday)
   if (day.lt.10) 
      dd="0"+d
   else
      dd = d
   end if
   if (initday.lt.10) 
      initdd="0"+d2
   else
      initdd = d2
   end if

   m1 = tostring(month)
   m2 = tostring(initmonth)
   if (month.lt.10) 
      mm="0"+m1
   else
      mm = m1
   end if
   if (initmonth.lt.10) 
      initmm="0"+m2
   else
      initmm = m2
   end if

   h = tostring(hour)
   h2 = tostring(inithour)
   if (hour.lt.10) 
      hh="0"+h
   else
      hh = h
   end if
   if (inithour.lt.10) 
      inithh="0"+h2
   else
      inithh = h2
   end if

   yy = tostring(yyyy)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Read in Stage IV file to get lat/lon re-gridding 

;   filename = "/home/ldehaan/MET_MODE_6.0/Config/GFS_limited_domain.nc"
   filename = "/data/downloaded/Forecasts/Model_Verification/StageIV/StageIV_QPE_2017123112.nc"
;   filename = "StageIV_QPE_2017121112.nc"
;    filename = "CNRFC_24QPF_2017121112_F024.nc"
   fin       = addfile(filename,"r")       
   
    lon       = fin->lon
    lat       = fin->lat

;;;;;;;  get WRF IVT and regrid  ;;;;;;;;;;;;;;;;
	 
; sum 3 hour totals for 8 time steps to get 24 hour total

hour24 = (/"12","09","06","03","00","21","18","15"/)
day24 = (/dd,dd,dd,dd,dd,dminus1,dminus1,dminus1/)
month24 = (/mm,mm,mm,mm,mm,mminus1,mminus1,mminus1/)
year24 = (/yy,yy,yy,yy,yy,yminus1,yminus1,yminus1/)

;;; 3 km domain (d02)   ;;;;;;;;;;;;;;;;;

       allfiles = new(8,string)

       do it = 0,7
;	 allfiles(it) = "/data/downloaded/WWRF-NRT/2018-2019/NRT_runs/COMET/hellyj/WWRF-Output-Data/WWRF-Two-III-"+inityyyy+"-"+initmm+"-"+initdd+"-"+inithh+"/wrfout_d02_"+year24(it)+"-"+month24(it)+"-"+day24(it)+"_"+hour24(it)+":00:00.nc"
	 allfiles(it) = "/data/downloaded/WWRF-NRT/2018-2019/NRT_runs_output/WWRF-Two-III-"+inityyyy+"-"+initmm+"-"+initdd+"-"+inithh+"/wrfout_d02_"+year24(it)+"-"+month24(it)+"-"+day24(it)+"_"+hour24(it)+"-00-00.nc"
;	 a[it] = addfile("/data/downloaded/WWRF-NRT/2018-2019/NRT_runs_output/WWRF-Two-III-"+inityyyy+"-"+initmm+"-"+initdd+"-"+inithh+"/wrfout_d02_"+year24[it]+"-"+month24[it]+"-"+day24[it]+"_"+hour24[it]+"-00-00.nc","r")
      end do

	 a = addfiles(allfiles,"r")

    wrflat = a[1]->XLAT(0,:,:)
    wrflon = a[1]->XLONG(0,:,:)

    printVarSummary(a)
    
	  rain24hr = a[7]->RAINBCKT(0,:,:) + a[6]->RAINBCKT(0,:,:) + a[5]->RAINBCKT(0,:,:) + a[4]->RAINBCKT(0,:,:) + a[3]->RAINBCKT(0,:,:) + a[2]->RAINBCKT(0,:,:) + a[1]->RAINBCKT(0,:,:) + a[0]->RAINBCKT(0,:,:) 
 rain24hr@_FillValue = -9999.

    rainbckt = a[7]->RAINBCKT(0,:,:)
    copy_VarCoords(rainbckt,rain24hr)
    copy_VarAtts(rainbckt,rain24hr)

;;; 9 km domain (d01)   ;;;;;;;;;;;;;;;;;

       allfiles9km = new(8,string)

       do it = 0,7
	 allfiles9km(it) = "/data/downloaded/WWRF-NRT/2018-2019/NRT_runs/COMET/hellyj/WWRF-Output-Data/WWRF-Two-III-"+inityyyy+"-"+initmm+"-"+initdd+"-"+inithh+"/wrfout_d01_"+year24(it)+"-"+month24(it)+"-"+day24(it)+"_"+hour24(it)+":00:00.nc"
      end do

      a9km = addfiles(allfiles9km,"r")

      wrflat9km = a9km[1]->XLAT(0,:,:)
      wrflon9km = a9km[1]->XLONG(0,:,:)

    
     rain24hr9km = a9km[7]->RAINBCKT(0,:,:) + a9km[6]->RAINBCKT(0,:,:) + a9km[5]->RAINBCKT(0,:,:) + a9km[4]->RAINBCKT(0,:,:) + a9km[3]->RAINBCKT(0,:,:) + a9km[2]->RAINBCKT(0,:,:) + a9km[1]->RAINBCKT(0,:,:) + a9km[0]->RAINBCKT(0,:,:) 
 rain24hr@_FillValue = -9999.

    rainbckt9km = a9km[7]->RAINBCKT(0,:,:)
    copy_VarCoords(rainbckt9km,rain24hr9km)
    copy_VarAtts(rainbckt9km,rain24hr9km)

    printVarSummary(wrflat9km)
    printVarSummary(wrflat)
;;;;;;;;;;   regrid 

	 Opt2 = True
	 Opt2@InterpMethod = "bilinear"
	 Opt2@WgtFileName = "wrf_to_latlon_wgt_precip.nc"	 
	 Opt2@SrcGridLat = wrflat
	 Opt2@SrcGridLon = wrflon
	 Opt2@SrcRegional = True
	 Opt2@DstRegional = True
	 Opt2@DstGridLat = lat
	 Opt2@DstGridLon = lon
	 Opt2@ForceOverwrite = True
	 Opt2@PrintTimings = True
	 Opt2@Debug = True

	 rain_regrid = ESMF_regrid(rain24hr,Opt2)

	 Opt = True
	 Opt@InterpMethod = "bilinear"
	 Opt@WgtFileName = "wrf9km_to_latlon_wgt_precip.nc"	 
	 Opt@SrcGridLat = wrflat9km
	 Opt@SrcGridLon = wrflon9km
	 Opt@SrcRegional = True
	 Opt@DstRegional = True
	 Opt@DstGridLat = lat
	 Opt@DstGridLon = lon
	 Opt@ForceOverwrite = True
	 Opt@PrintTimings = True
	 Opt@Debug = True

	 rain_regrid9km = ESMF_regrid(rain24hr9km,Opt)

;;;;;;;;;;
 
	 precip = rain_regrid
	 precip!0 = "lat"
    	 precip!1 = "lon"
         precip&lat = lat
         precip&lon = lon
         precip&lat@units = "degrees_north"
         precip&lon@units = "degrees_east"
	 precip@long_name="24 hour accumulated precip"
	 precip@units="mm"
	 precip@init_time=inityyyy+initmm+initdd+"_"+inithh+"0000"

	 precip9km = rain_regrid9km
	 precip9km!0 = "lat"
    	 precip9km!1 = "lon"
         precip9km&lat = lat
         precip9km&lon = lon
         precip9km&lat@units = "degrees_north"
         precip9km&lon@units = "degrees_east"
	 precip9km@long_name="24 hour accumulated precip"
	 precip9km@units="mm"
	 precip9km@init_time=inityyyy+initmm+initdd+"_"+inithh+"0000"


;;;;;;;;; define time variables  ;;;;;
	
	 time = new(1,double)
	 uname = "hours since "+yyyy+"-"+mm+"-"+dd+" "+hh
;	 print(uname)
	 time@units=uname
	 time = 0
	 printVarSummary(time)
	 
	 forecast_reference_time = new(1,double)
	 forecast_reference_time@units = "hours since "+inityyyy+"-"+initmm+"-"+initdd+" "+inithh
	 forecast_reference_time@init_time=inityyyy+initmm+initdd+"_"+inithh+"0000"
	 forecast_reference_time@valid_time=yyyy+mm+dd+"_"+hh+"0000"
	 forecast_reference_time = 0

;;;;;;;;;;; output WRF IVT to netcdf file

       system("/bin/rm -f wrf.24hrprecip."+inityyyy+initmm+initdd+inithh+"_"+yyyy+mm+dd+hh+".nc")  ; remove any pre-existing file
       ncdf = addfile("wrf.24hrprecip."+inityyyy+initmm+initdd+inithh+"_"+yyyy+mm+dd+hh+".nc" ,"c")  ; open output netCDF file

    ;===================================================================
    ; create global attributes of the file (optional)
    ;===================================================================
       fAtt               = True            ; assign file attributes
       fAtt@Conventions   = "CF-1/0"
       fAtt@creation_date = systemfunc ("date")
       fileattdef( ncdf, fAtt )            ; copy file attributes

    ;===================================================================
    ; make time an UNLIMITED dimension; recommended  for most applications
    ;===================================================================
       filedimdef(ncdf,"time",-1,True) 

    ;===================================================================
    ; output variables directly; NCL will call appropriate functions
    ; to write the meta data associated with each variable
    ;===================================================================
       ncdf->precip = precip
       ncdf->time=time
       ncdf->forecast_reference_time=forecast_reference_time

;;;;;;;;;;; output WRF IVT to netcdf file 9km ;;;;;;;;

       system("/bin/rm -f wrf_9km.24hrprecip."+inityyyy+initmm+initdd+inithh+"_"+yyyy+mm+dd+hh+".nc")  ; remove any pre-existing file
       ncdf = addfile("wrf_9km.24hrprecip."+inityyyy+initmm+initdd+inithh+"_"+yyyy+mm+dd+hh+".nc" ,"c")  ; open output netCDF file

    ;===================================================================
    ; create global attributes of the file (optional)
    ;===================================================================
       fAtt               = True            ; assign file attributes
       fAtt@Conventions   = "CF-1/0"
       fAtt@creation_date = systemfunc ("date")
       fileattdef( ncdf, fAtt )            ; copy file attributes

    ;===================================================================
    ; make time an UNLIMITED dimension; recommended  for most applications
    ;===================================================================
       filedimdef(ncdf,"time",-1,True) 

    ;===================================================================
    ; output variables directly; NCL will call appropriate functions
    ; to write the meta data associated with each variable
    ;===================================================================
       ncdf->precip = precip9km
       ncdf->time=time
       ncdf->forecast_reference_time=forecast_reference_time


;;;;;	Plot to check results ;;;;

; We generate plots, but what kind do we prefer?
;  type = "x11"
; type = "pdf"
; type = "ps"
; type = "ncgm"
;   wks = gsn_open_wks(type,"ivt.regrid.check")
;   plot = new(2,graphic)
;  res                               = True	
;  res@gsnDraw			    = False
;  res@gsnFrame			    = False
;  res@gsnAddCyclic		    = False
;  res@mpOutlineOn           = True                ; turn on map outline
;  res@mpOutlineBoundarySets = "USStates"          ; turn on state boundaries
;  res@gsnSpreadColors       = True                ; use full range of colors
;  res@mpMinLatF  = 19
;  res@mpMaxLatF  = 48                             ; choose subregion           
;  res@mpMinLonF  = 198
;  res@mpMaxLonF  = 252
;  res@cnLineDrawOrder = "PreDraw"
;  res@cnFillOn          = True              ; color plot desired
;   res@cnLevelSelectionMode="ManualLevels"
;   res@cnMinLevelValF = 0
;   res@cnMaxLevelValF = 520
;   res@cnLevelSpacingF = 40
;  plot(0) = gsn_csm_contour_map(wks,ivtwrf,res)
;  plot(1) = gsn_csm_contour_map(wks,ivtwrf,res)
;  gsn_panel(wks,plot,(/2,1/),False)

end
