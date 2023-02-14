c     read MET/MODE object text file and create an array of stats

      character*650 header

c     variables for both individual and paired objects
      character*4 version
      integer n_valid, grid_res
      character*3 desc,fcst_var,obs_var,model
      character*1 fcst_lev1,obs_lev1,fcst_lev2,obs_lev2,cobj
      integer fcst_lead,fcst_accum,obs_lead,obs_accum
      character*17 fcst_valid,obs_valid
      integer fcst_rad,obs_rad
      character*7 fcst_thr,obs_thr
      character*6 obtype
      character*11 object_cat,object_id

c     variables for either individual or paired (but not both)
      real centroid_x,centroid_y,centroid_lat,centroid_lon
      real axis_ang,length,width
      integer area,area_filter,area_thresh
c      real area
      real curvature,curvature_x,curvature_y,complexity
      real intensity_10,intensity_25,intensity_50,intensity_75
      real intensity_90,intensity_50b,intensity_sum
      real boundary_dist, convex_hull_dist,angle_diff(25),area_ratio
      real centroid_dist(25),intersection_over_area,complexity_ratio
      real percentile_intensity_ratio,interest
      real aspect_diff, curvature_ratio
      integer intersection_area(25),union_area(25),symmetric_diff

c     character versions of the variables
      character*9 ccentroid_x,ccentroid_y,ccentroid_lat,ccentroid_lon
      character*9 caxis_ang,clength,cwidth
      character*9 carea,carea_filter,carea_thresh
      character*4 carea_ratio
      character*9 ccurvature,ccurvature_x,ccurvature_y,ccomplexity
      character*9 cintensity_10,cintensity_25,cintensity_50
      character*9 cintensity_90,cintensity_50b
      character*10 cintensity_sum
      character*9 cboundary_dist,cconvex_hull_dist,cangle_diff
      character*9 ccentroid_dist,cintersection_over_area
      character*9 cpercentile_intensity_ratio,cinterest
      character*9 ccomplexity_ratio,cintensity_75
      character*9 cintersection_area,cunion_area,csymmetric_diff
      character*9 caspect_diff, ccurvature_ratio
      
      character*180 filename,dirname
      character*200 command
      character*60 fileout
      character*8 validday,validday2
      character*2 NA,validhr
      character*3 forhour,model3,lead
      character*8 thresh
      character*7 model_loop
      character*11 next,exper,truth

      real rnext,ratio(7,25)
      real minlength,goodangle,good90,maxlen
c     read for each object in a given forecast time
      real f90(25), ang_for(25), o90(25), ang_obs(25),length_obs(25)
      real obs_area(25),fcst_area(25), clat(25), clon(25)
c     the "correct" (chosen) for each forecast time
      real error90(7,25), anal90(7,25), analang(7,25), ang_err(7,25)
      real Aobs(7,25),Afcst(7,25),id(7,25)
      character*5 fcstname(25),obsname(25)
      character*11 matched,location,pairedname(25)
      logical there,there1
      integer nomatchflag(25),temp,empty,obsobject(25),max

c      do ilead = 1,5
      do ilead = 5,5
         if (ilead.eq.1) lead ="48"
         if (ilead.eq.2) lead ="72"
         if (ilead.eq.3) lead ="96"
         if (ilead.eq.4) lead ="120"
         if (ilead.eq.5) lead ="144"

         print*,"**** ILEAD ",lead
c         do iexper = 1,5
         do iexper = 1,2
       if (iexper.eq.1) exper = "analysis"
       if (iexper.eq.2) exper = "piecewise"
c       if (iexper.eq.1) exper = "80Lev"
c       if (iexper.eq.2) exper = "60Lev"
       if (iexper.eq.3) exper = "2x3km_48lv"
       if (iexper.eq.4) exper = "PBLJet_60lv"
       if (iexper.eq.5) exper = "control"

c      exper = "Ra_SWphys"
c      exper = "dfi"

       do itruth = 2,2
          if (itruth.eq.1) truth = "StageIV"
          if (itruth.eq.2) truth = "vs_control"
          if (itruth.eq.3) truth = "vs_0hr"

c          do ilocation = 1,5
          do ilocation = 1,1
             if (ilocation.eq.1)  location = "Oroville"
             if (ilocation.eq.2)  location = "Russian1"
             if (ilocation.eq.3)  location = "Russian2"
             if (ilocation.eq.4)  location = "Prado"
             if (ilocation.eq.5)  location = "Seattle"
c
      numthresh = 7
c      do ithresh = 1,numthresh
      do ithresh = 1,6
         if (ithresh.eq.1) thresh = "13mm_d01"
         if (ithresh.eq.2) thresh = "25mm_d01"
         if (ithresh.eq.3) thresh = "50mm_d01"
         if (ithresh.eq.4) thresh = "13mm_d02"
         if (ithresh.eq.5) thresh = "25mm_d02"
         if (ithresh.eq.6) thresh = "50mm_d02"
         if (ithresh.eq.7) thresh = "500"
         
      do imodel = 4,4
         model_loop = ""
         if (imodel.eq.1) model_loop = "GFS"
         if (imodel.eq.2) model_loop = "GEFS"
         if (imodel.eq.3) model_loop = "CMCENS"
         if (imodel.eq.4) model_loop = "WestWRF"
         if (imodel.eq.5) model_loop = "NAM"

c     initialize
      
         ratio = -999.
         max = -99
         max2 = -999.
         error90 = -999.
         ang_err = -999.
         anal90 = -999.
         analang = -999.
         nomatchflag = 0
         goodangle = -999.
         good90 = -999.
         Aobs = -999.
         Afcst = -999.
         
cccccccccccccccc  Loop thru each forecast cccccccccccccc
      
         if (lead.eq."144") numifor = 6
         if (lead.eq."120") numifor = 5
         if (lead.eq."96") numifor = 4
         if (lead.eq."72") numifor = 3
         if (lead.eq."48") numifor = 2
         if (lead.eq."24") numifor = 1

      do iforecast = 2,numifor
         
         fcstname =""
         obsname = ""
         matched = ""
         forhour = ""
         pairedname = ""

            if (iforecast.eq.1) forhour="24"
            if (iforecast.eq.2) forhour="48"
            if (iforecast.eq.3) forhour="72"
            if (iforecast.eq.4) forhour="96"
            if (iforecast.eq.5) forhour="120"
            if (iforecast.eq.6) forhour="144"


c**********     Open MODE output txt files  ****************
         
c          dirname="ls /data/downloaded/SCRATCH/ldehaan_scratch/"//
c     +   "Sensitivity/MODE_output/Oroville_144hr_lead_dfi/vs_control/"//
c     +   trim(thresh)//"/mode_"//trim(model_loop)//"_*_"//
c     +   trim(forhour)//
c     +   "*0000V_000000A_obj.txt > filename.txt"      

          dirname="ls /data/downloaded/SCRATCH/ldehaan_scratch/"//
     +   "Sensitivity/MODE_output/"//trim(location)//"_"//trim(lead)//
     +   "hr_lead_"//trim(exper)//"/"//trim(truth)//"/"//
     +   trim(thresh)//"/mode_"//trim(model_loop)//"*_"//
     +   trim(forhour)//
     +   "*0000V_000000A_obj.txt >& filename.txt"      
c          print*,dirname

          call system("rm filename.txt")
          call system(dirname)

          open(unit=18,file='filename.txt')
          read(18,'(a180)') filename           
          close(18)

ccc     extract stats if file exists   **************************

       inquire(file=filename,exist=there)

       print*,filename
       if(there) then

          
c     check if there are any data lines in the file

          call execute_command_line('rm wc.txt')
          write(command,"(A7,A180,A9)") "wc -l < ",filename," > wc.txt"
          call execute_command_line(command)
          open(unit=19,file='wc.txt')
          read(19,*) iline

         open(14,file=filename)
      
         read(14,'(a)') header
         io = 0

c     initialize variables for each forecast time 
         ang_for = -999.
         ang_obs = -999.
         length_obs = -999.
         f90 = -999.
         o90 = -999.
         obs_area = -999.
         fcst_area = -999.
         clon = -999.
         clat = -999.
         numobjects = 1

c     read until end of file

         do while ((io.ge.0).and.(iline.gt.1))

c     since many variables are sometimes a number and sometimes "NA" (character)
c     read all as character, and then convert to number based on object_id
c     -which will be 11 characters long for a paired object and 
c      5 characters long for an individual object
c   add v8 extras: N_VALID, GRID_RES, OBTYPE, ASPECT_DIFF, CURVATURE_RATIO, and remove AREA_FILTER

         read(14,*,IOSTAT=io) 
     +     version,model,n_valid,grid_res,desc,fcst_lead,fcst_valid,
     +     fcst_accum,obs_lead,obs_valid,obs_accum,fcst_rad,fcst_thr,
     +     obs_rad,obs_thr,fcst_var,fcst_lev1,fcst_lev2,obs_var,
     +     obs_lev1,obs_lev2,obtype,object_id,object_cat,
     +     ccentroid_x,ccentroid_y,ccentroid_lat,ccentroid_lon,
     +     caxis_ang,clength,cwidth,carea,carea_thresh,
     +     ccurvature,ccurvature_x,ccurvature_y,ccomplexity,
     +     cintensity_10,cintensity_25,cintensity_50,cintensity_75,
     +     cintensity_90,cintensity_50,cintensity_sum,
     +     ccentroid_dist,
     +     cboundary_dist,cconvex_hull_dist,cangle_diff,
     +     caspect_ratio,carea_ratio,
     +     cintersection_area,cunion_area,csymmetric_diff,
     +     cintersection_over_area,ccurvature_ratio, ccomplexity_ratio,
     +     cpercentile_intensity_ratio,cinterest
      
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c     read stats from individual (unpaired, but combined) objects (change character into real)

         if((len(trim(object_id)).lt.7).and.
     +        (len(trim(object_id)).gt.0)) then
            read(carea,'(i5)') area
            read(ccentroid_x,'(f8.5)') centroid_x
            read(ccentroid_y,'(f8.5)') centroid_y
            read(ccentroid_lat,'(f8.5)') centroid_lat
            read(ccentroid_lon,'(f8.5)') centroid_lon
c     if axis angle is reported in scientific form (includes an "e"), assume it's close to 0
            if (index(caxis_ang,"e").eq.0) then
               read(caxis_ang,'(f8.5)') axis_ang 
            else
               axis_ang =0.0
               print*,"assume axis angle close to 0 "
            endif
            read(clength,'(f8.5)') length
            read(cwidth,'(f8.5)') width
            read(ccurvature,'(f8.5)') curvature
            read(ccurvature_x,'(f8.5)') curvature_x
            read(ccurvature_y,'(f8.5)') curvature_y
            if (ccomplexity.ne."0") then
               read(ccomplexity,'(f8.5)') complexity
            else
               complexity = 0.0
            endif
c     in a very few cases the object is so small MODE can't compute intensity thresholds
            if (index(cintensity_10,"NA").eq.0) then
               read(cintensity_10,'(f8.5)') intensity_10
               read(cintensity_25,'(f8.5)') intensity_25
               read(cintensity_50,'(f8.5)') intensity_50
               read(cintensity_75,'(f8.5)') intensity_75
               read(cintensity_90,'(f8.5)') intensity_90
               read(cintensity_sum,'(f8.5)') intensity_sum
            else
               intensity_10 = 0
               intensity_25 = 0
               intensity_50 = 0
               intensity_75 = 0
               intensity_90 = 0
               intensity_sum = 0
            endif

c     find 90th percentile and angle for forecast and obs

            if (imodel.eq.5) centroid_lon = 360. + centroid_lon

c     FORECAST Objects
            if (index(object_id,"CF").gt.0) then
               f90(numobjects) = intensity_90
               fcst_area(numobjects) = area
               ang_for(numobjects) = axis_ang
               fcstname(numobjects) = object_id
               clat(numobjects) = centroid_lat
               clon(numobjects) = centroid_lon
               numobjects=numobjects+1
            endif
c     OBSERVED Objects

            if (index(object_id,"CO").gt.0) then
               o90(numobjects) = intensity_90
               obs_area(numobjects) = area
               obsname(numobjects) = object_id
               ang_obs(numobjects) = axis_ang
               length_obs(numobjects) = length
               numobjects=numobjects+1
            endif


ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c     read stats from paired objects (change character into real)

         else
         if((len(trim(object_id)).gt.6).and.(index(object_id,"C").gt.0)) 
     +           then
            read(ccentroid_dist,'(f8.5)') centroid_dist(numobjects)
            read(cangle_diff,'(f8.5)') angle_diff(numobjects)
            read(cintersection_area,'(i5)')intersection_area(numobjects)
            read(cunion_area,'(i5)') union_area(numobjects)
            pairedname(numobjects) = object_id
            numobjects = numobjects+1
         endif

      endif
      enddo
      endif
c     end read of file (if there)
           
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      obsobject(iforecast) = 0

      do iobject = 1,numobjects-1
c                                                  for each obs object
         if (len(trim(obsname(iobject))).gt.0) then
            obsobject(iforecast) = obsobject(iforecast)+1
            anal90(iforecast,obsobject(iforecast)) = o90(iobject)
            analang(iforecast,obsobject(iforecast)) = ang_obs(iobject)
            Aobs(iforecast,obsobject(iforecast)) = obs_area(iobject)
c            print*,iforecast,obsobject(iforecast),obs_area(iobject),
c     +           iobject,obsname(iobject),o90(iobject)

c                                                  look for paired objects that include the obs object            
            do ipobj = 1,numobjects-1
c               print*,ipobj,"paired ",pairedname(ipobj),
c     +              iobject," obs ",obsname(iobject),
c     +         index(trim(pairedname(ipobj)),trim(obsname(iobject)))
               if ((len(trim(pairedname(ipobj))).gt.0).and.
     +    (index(trim(pairedname(ipobj)),trim(obsname(iobject))).gt.0))
     +              then
c                                                  iobject refers to single (combined, but not paired) obs object
c                                                  ipobj refers to paired object with obs object
                  ratio(iforecast,obsobject(iforecast))=
     +                 real(intersection_area(ipobj))

c                                                  find forecast objects paired to obs object
                  do ifobj = 1,numobjects-1
                     if ((len(trim(fcstname(ifobj))).gt.0).and.
     +                (index(pairedname(ipobj),
     +                    trim(fcstname(ifobj))).gt.0)) then
c                  print*,"in forecast ",ifobj,fcst_area(ifobj),
c     +                       iforecast,obsobject(iforecast),
c     +                       pairedname(ipobj)," ",fcstname(ifobj)
                error90(iforecast,obsobject(iforecast)) = f90(ifobj)
                ang_err(iforecast,obsobject(iforecast)) = ang_for(ifobj)
                Afcst(iforecast,obsobject(iforecast)) = fcst_area(ifobj)
                     endif
                  enddo
               endif
            enddo
         endif
      enddo

c     end iforecast
      enddo
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      
      do iobj = 1, numifor
         if (obsobject(iobj).gt.max) max = obsobject(iobj)
      enddo

c     this code outputs objects from different days - no matching is implied in the 90th and areaM outputfiles
c     match obs objects from each forecast lead time based on obs area

c     define object id from longest forecast
c      do iobj = 1, obsobject(numifor)
c         id(iobj) = Aobs(numifor,iobj)
c      enddo         
c      do iforecast = 1,numifor-1
c         do iobj = 1, obsobject(iforecast)
c            if (Aobs(iforecast,iobj).ne.id(iobj)) then
c               print*,"switching ",iforecast,iobj,Aobs(iforecast,iobj)
c               do iobj2 = 1,obsobject(iforecast)
c                  if (Aobs(iforecast,iobj2).eq.id(iobj)) then
c                     temp1=Aobs(iforecast,iobj)                     
c                     temp2=ratio(iforecast,iobj)                     
c                     temp3=Afcst(iforecast,iobj)                     
c                     temp4=anal90(iforecast,iob)                     
c                     temp5=error90(iforecast,iobj)                     
c                     Aobs(iforecast,iobj) = Aobs(iforecast,iobj2)
c                     Afcst(iforecast,iobj) = Afcst(iforecast,iobj2)
c                     anal90(iforecast,iobj) = anal90(iforecast,iobj2)
c                     error90(iforecast,iobj) = error90(iforecast,iobj2)
c                     ratio(iforecast,iobj) = ratio(iforecast,iobj2)
c                     Aobs(iforecast,iobj2) = temp1
c                     Afcst(iforecast,iobj2) = temp3
c                     anal90(iforecast,iobj2) = temp4
c                     error90(iforecast,iobj2) = temp5
c                     ratio(iforecast,iobj2) = temp2
c                  endif
c               enddo
c            endif
c            print*,"iforecast ",iforecast," iobj ",iobj,id(iobj),
c     +           Aobs(iforecast,iobj)
c         enddo
c      enddo
            
      
      do iobj = 1,max

         write(cobj,'(I1)') iobj
         filename="/data/downloaded/SCRATCH/ldehaan_scratch/"//
     +   "Sensitivity/MODE_output/"//trim(location)//"_"//trim(lead)//
     +   "hr_lead_"//trim(exper)//"/"//trim(truth)//"/"//
     +   trim(thresh)//"/areaM_"//trim(thresh)//"_"
     +   //trim(model_loop)//"_"//cobj
     +   //".txt"
         open(15,file =filename)

c         filename="/data/downloaded/SCRATCH/ldehaan_scratch/"//
c     +   "Sensitivity/MODE_output/"//trim(location)//"_144hr_lead_"//trim(exper)//"/"//trim(truth)//"/"//
c     +   trim(thresh)//"/angle_"//trim(thresh)//"_"//trim(model_loop)
c     +   //"_"//validday//validhr//".txt"
c         open(17,file =filename)

         filename="/data/downloaded/SCRATCH/ldehaan_scratch/"//
     +   "Sensitivity/MODE_output/"//trim(location)//"_"//trim(lead)//
     +    "hr_lead_"//trim(exper)//"/"//trim(truth)//"/"//
     +   trim(thresh)//"/90thP_"//trim(thresh)//"_"
     +   //trim(model_loop)//"_"//cobj
     +   //".txt"

         open(19,file =filename)

         write(15,'(7f10.2)'),ratio(1:7,iobj)
         write(15,'(7f10.2)'),Aobs(1:7,iobj)
         write(15,'(7f10.2)'),Afcst(1:7,iobj)
         write(19,'(7f11.2)'),anal90(1:7,iobj)
         write(19,'(7f11.2)'),error90(1:7,iobj)

         close(15)
         close(19)

      enddo

c     enddo imodel
      enddo
c     enddo ithresh
      enddo

c     enddo ilocation
      enddo
c     enddo itruth
      enddo
c     enddo iexper
      enddo
c     enddo ilead
      enddo      

      end
