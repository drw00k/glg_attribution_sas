/***********************************************************
*
* Project:       
* Program Name:  import_analog_data.sas
* Author:        U-degobah\rsowers
*
* Creation Date: <2015-08-25 16:23:49> 
* Time-stamp:    <2015-10-19 19:22:29>
*
* Input:
*
* Output:
*
* Purpose:
*
* Modified:
*
************************************************************/

options compress=YES;

%macro import_analog_data(projectPath = C:\cygwin64\home\rsowers\projects\glg ,
                          currentFile = &projectPath\data\raw\text\current\full_data_new_final.txt ,
                          convFile    = &projectPath\data\raw\text\current\full_conversion_values.txt ,
                          histFile    = &projectPath\data\raw\text\current\GLG_Full_Monthly_History_3_1.csv ,
                          rawPath     = &projectPath\data\raw ,
                          currentDS   = current_data_raw );

    libname rawlib "&rawPath";

    data tmp_hist_data;
        infile "&histFile" DSD DLM = "," truncover firstobs = 2;
        input
            week :$10.
            site :$70.
            total_media_cost :10.
            impressions :10.
            clicks :10.
            total_pageloads :10.
            total_real_conversions :10.
            total_value :10.;
    run;

    proc sql noprint;
        create table rawlib.glg_hist_data as select
            week,
            site,
            total_media_cost format=dollar12.2,
            impressions format=comma12.,
            clicks format=comma12.,
            total_pageloads format=comma12.,
            total_real_conversions format=comma12.,
            total_value format=dollar12.2
            from tmp_hist_data
            order by week, site; 
        quit;
    run;

    proc insight data = rawlib.glg_hist_data; run;
    
    endsas;





    

/***********************************************************
* Import the conversion data
************************************************************/
        
    data tmp_conv_data;
        infile "&convFile" DSD DLM = "," truncover firstobs = 2;
        input
            txt_date :$8.
            user_id :$40.
            site :$70.
            value :10.;
    run;

    proc sql noprint;
        create table rawlib.full_conv_data as select
            input(txt_date, YYMMDD8.) as date format=YYMMDD10.,
            ((year(calculated date)*100)+month(calculated date)) as month,
            ((year(calculated date)*1000)+(intck("WEEK",intnx("YEAR",calculated date,0),calculated date)+1)) as week,
            user_id,
            upper(site) as site,
            value
            from tmp_conv_data;
        quit;
    run;
    
/***********************************************************
* Import the current campaign data
************************************************************/

    data tmp_current_data;
        infile "&currentFile" DSD DLM = "|" truncover firstobs = 2;
        input
        campaign_name      :$70.
        txt_date           :$8.
        site               :$70.
        section            :$70.
        placement          :$70.
        strategy           :$70.
        channel            :$70.
        ad_type            :$70.
        audience           :$70.
        geography          :$70.
        ad_size            :$20.
        ad_name            :$70.
        impressions        :10.
        clicks             :10.
        total_media_cost   :12.2
        total_pageloads    :10.
        post_imp_pageloads :10.
        post_clk_pageloads :10.;
    run;

    proc sql noprint;
        create table rawlib.&currentDS as select
            input(txt_date, YYMMDD8.) as date format=YYMMDD10.,
            ((year(calculated date)*100)+month(calculated date)) as month,
            ((year(calculated date)*1000)+(intck("WEEK",intnx("YEAR",calculated date,0),calculated date)+1)) as week,
            trim(upcase(campaign_name)) as campaign_name,
            trim(upcase(site))       as site,
            trim(upcase(section))    as section,
            trim(upcase(placement))  as placement,
            trim(upcase(strategy))   as strategy,
            trim(upcase(channel))    as channel,
            trim(upcase(ad_type))    as ad_type,
            trim(upcase(audience))   as audience,
            trim(upcase(geography))  as geography,
            trim(upcase(ad_size))    as ad_size,
            trim(upcase(ad_name))    as ad_name,
            impressions format=comma10.,
            clicks format=comma10.,
            total_media_cost format=dollar12.2,
            total_pageloads as total_conv format=comma10.,
            post_imp_pageloads format=comma10.,
            post_clk_pageloads format=comma10.
            from tmp_current_data;
        quit;
    run;

%mend import_analog_data;

%import_analog_data;

