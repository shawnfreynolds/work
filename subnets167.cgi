#!/usr/bin/perl

        $pdhcp = 1;
        $popen = 1;
        $perror = 1;
        $pissue = 1;
        $proute = 1;

@dns = `host -l allina.com |grep netn | grep "has address 167.177"`;
#@dns = `host -l allina.com localhost |grep netn | grep "has address 167.177"`;

foreach (@dns) {
	s/\.allina\.com//g;
   @string = split(" ",$_);
	@hname= split(/\-/,$string[0]);

   @dns_octs = split(/\-/, $string[0]);
   @start_octs = split(/\./, $string[3]);

   if ($dns_octs[5] =~ m/\d/ &&
   	$dns_octs[6] =~ m/\d/) {
      $dns_subnet = "255.255.$dns_octs[5].$dns_octs[6]";

		if ($dns_subnet eq "255.255.255.255") {
			$end_octs3 = $start_octs[2] + 0;
			$end_octs4 = $start_octs[3] + 0;
		}
      elsif ($dns_subnet eq "255.255.255.254") {
      	$end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 1;
      }
      elsif ($dns_subnet eq "255.255.255.252") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 3;
      }
      elsif ($dns_subnet eq "255.255.255.248") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 7;
      }
      elsif ($dns_subnet eq "255.255.255.240") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 15;
      }
      elsif ($dns_subnet eq "255.255.255.224") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 31;
      }
      elsif ($dns_subnet eq "255.255.255.192") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 63;
      }
      elsif ($dns_subnet eq "255.255.255.128") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 127;
      }
      elsif ($dns_subnet eq "255.255.255.0") {
         $end_octs3 = $start_octs[2] + 0;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.254.0") {
         $end_octs3 = $start_octs[2] + 1;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.252.0") {
         $end_octs3 = $start_octs[2] + 3;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.248.0") {
         $end_octs3 = $start_octs[2] + 7;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.240.0") {
         $end_octs3 = $start_octs[2] + 15;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.224.0") {
         $end_octs3 = $start_octs[2] + 31;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.192.0") {
         $end_octs3 = $start_octs[2] + 63;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.128.0") {
         $end_octs3 = $start_octs[2] + 127;
         $end_octs4 = $start_octs[3] + 255;
      }
      elsif ($dns_subnet eq "255.255.0.0") {
     		$end_octs3 = $start_octs[2] + 255;
         $end_octs4 = $start_octs[3] + 255;
      }
		else {
		}

	   if ($dns_octs[8] =~ m/\d/ &&
      	$dns_octs[9] =~ m/\d/) {
			push @data, ("$string[3] - $start_octs[0].$start_octs[1].$end_octs3.$end_octs4 - $dns_subnet - $start_octs[0].$start_octs[1].$dns_octs[8].$dns_octs[9] - $string[0]\n");
         $found{$string[3]} = 1;
		}
		else {
			push @data, ("$string[3] - $start_octs[0].$start_octs[1].$end_octs3.$end_octs4 - $dns_subnet - UNKNOWN - $string[0]\n");
         $found{$string[3]} = 1;
		}

		$end_octs3 = "";
		$end_octs4 = "";
                       	}
     	else {
			push @data, ("$string[3] - UNKNOWN - UNKNOWN - UNKNOWN - $string[0]\n");
         $found{$string[3]} = 1;
      }
}

use CGI ':standard';
use CGI::Carp qw/fatalsToBrowser/;
print header;
#### create HTML
print "
        <html>
        <head>
        <title>Advanced Network Services - Subnet Breakdown</title>
        <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=ISO-8859-1\">

        <style type=\"text/css\">
        /* Sortable tables */
        table.sortable a.sortheader {
            background-color:#94DBDE;
            color:#0000FF;
            font-weight: bold;
            text-decoration: none;
            display: block;
        }
        table.sortable span.sortarrow {
            color:#0000FF;
            text-decoration: none;
        }
        </style>
        </head>\n

        <body>
        <center>

        <table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">
        <TR ALIGN=CENTER>
            <td bgcolor=\"#000066\" <b><font size=\"5\" color=\"#FFFFFF\">ANS - Subnet Breakdown</td>
          </tr>
        </table>

        <table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">
        <TR ALIGN=CENTER>
            <td bgcolor=\"#CCDDEE\"><b>For the 167.177 networkss</td>
          </tr>
        </table>

        <table id=\"t1\" class=\"sortable\">
        <TR ALIGN=CENTER>
	    <th width=\"200\" bgcolor=\"#CEDFEF\">Network</th>
            <th width=\"100\" bgcolor=\"#CEDFEF\">Subnet</th>
	    <th width=\"100\" bgcolor=\"#CEDFEF\">Gateway</th>
	    <th width=\"370\" bgcolor=\"#CEDFEF\">Description</th>
	    <th width=\"50\" bgcolor=\"#CEDFEF\">Usable</th>
	    <th width=\"180\" bgcolor=\"#CEDFEF\">Comment</th>
        </tr>";


# sort via a sub routine
@data = sort sorted_by @data;
$first = "yes";
$fcolor = "black";

foreach (@data) {
        
        @info = split(/\ \-\ /, $_);
	
	@start = split(/\./, $info[0]);
	@end = split(/\./, $info[1]);
        
        if ($info[2] eq "255.255.255.255") { $totalip = "1"}
        elsif ($info[2] eq "255.255.255.254") { $totalip = "3"}
        elsif ($info[2] eq "255.255.255.252") { $totalip = "3"}
        elsif ($info[2] eq "255.255.255.248") { $totalip = "7"}
        elsif ($info[2] eq "255.255.255.240") { $totalip = "15"}
        elsif ($info[2] eq "255.255.255.224") { $totalip = "31"}
        elsif ($info[2] eq "255.255.255.192") { $totalip = "63"}
        elsif ($info[2] eq "255.255.255.128") { $totalip = "127"}
        elsif ($info[2] eq "255.255.255.0") { $totalip = "255"}
        elsif ($info[2] eq "255.255.254.0") { $totalip = "511"}
        elsif ($info[2] eq "255.255.252.0") { $totalip = "1023"}
        elsif ($info[2] eq "255.255.248.0") { $totalip = "2047"}
        elsif ($info[2] eq "255.255.240.0") { $totalip = "4095"}
        elsif ($info[2] eq "255.255.224.0") { $totalip = "8191"}
        elsif ($info[2] eq "255.255.192.0") { $totalip = "16383"}
        elsif ($info[2] eq "255.255.128.0") { $totalip = "32767"}
        elsif ($info[2] eq "255.255.0.0") { $totalip = "65535"}
        elsif ($info[2] eq "255.254.0.0") { $totalip = "131071"}
        elsif ($info[2] eq "255.252.0.0") { $totalip = "262143"}
        elsif ($info[2] eq "255.248.0.0") { $totalip = "524287"}
        elsif ($info[2] eq "255.240.0.0") { $totalip = "1048575"}
        elsif ($info[2] eq "255.224.0.0") { $totalip = "2097151"}
        elsif ($info[2] eq "255.192.0.0") { $totalip = "4194303"}
        elsif ($info[2] eq "255.0.0.0") { $totalip = "8388607"}
        else {}
        
	#### if there is any open space...
	
	if (not($first eq "yes" || $prevend[0] eq "UNKNOWN")) {
                
 		if (not($start[0] eq $prevstart[0] && $start[1] eq $prevstart[1] && $start[2] eq $prevstart[2] && $start[3] eq $prevstart[3])) {
                        
                        
                        if ($start[1] eq $prevend[1]) {
                                $test2 = $start[2] - $prevend[2];
                                $test3 = $start[3] - $prevend[3] - 1;
                                $free = $test2 * 256 + $test3;
                                
                                if ($start[2] eq $prevend[2]) {
                                        $test2 = $start[2] - $prevend[2];
                                        $test3 = $start[3] - $prevend[3] - 1;
                                        $free = $test2 * 256 + $test3;
                                }
                                else {
                                        $test2 = $start[2] - $prevend[2] - 1;
                                        $test3 = 255 - $prevend[3];
                                        $free = $test2 * 256 + $test3 + $start[3];
                                }
                                #print "$prevend[1].$prevend[2].$prevend[3] - $start[1].$start[2].$start[3] $test2 - $test3 - $free";
                        }
                        else {
                                $test1 = $start[1] - $prevend[1];
                                $test2 = $start[2] - $prevend[2];
                                $test3 = $start[3] - $prevend[3] - 1;
                                $free = ($test1 * 65536) + ($test2 * 256) + $test3;
                        }
        
                        if (not($free eq 0)) {
                                
                                ### first open start
                                $new1 = $prevend[1];
                                $new2 = $prevend[2];
                                $new3 = $prevend[3] + 1;
                        
                                if ($new3 eq 256) {
                                        $new2 = $prevend[2] + 1;
                                        $new3 = 0;
                                        
                                        if ($new2 eq 256) {
                                                $new1 = $prevend[1] + 1;
                                                $new2 = 0;                                        
                                        }
                                }
                                
                                ### last open
                                $enew1 = $start[1];
                                $enew2 = $start[2];
                                $enew3 = $start[3] - 1;
                                
                                if ($enew3 eq -1) {
                                        $enew2 = $start[2] - 1;
                                        $enew3 = 255;
                                        
                                        if ($enew2 eq -1) {
                                                $enew1 = $start[1] - 1;
                                                $enew2 = 255;
                                        }
                                }
                                
                                if ($free < 0) {
                                        $free = "Error";
                                }
                        
	
                                if ($free eq "Error") {
                                        if ($perror eq "1") {
                                $color = "orange";
                                        print "  <TR><TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$start[0].$new1.$new2.$new3 - $start[0].$enew1.$enew2.$enew3</TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$free</TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=RIGHT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=CENTER bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">Overlapping subnet</TD></TR>\n";
                                        }
                                }
                                else {
                                        if ($popen eq "1") {
                                $color = "pink";
                                        print "  <TR><TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$start[0].$new1.$new2.$new3 - $start[0].$enew1.$enew2.$enew3</TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$free Hosts open</TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=RIGHT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD>
                                             <TD ALIGN=CENTER bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\"></TD></TR>\n";
                                        }       
                                }       
                        }
                }
	}
                if ($pissue eq "1" || $proute eq "1") {
		$color = "white";
		        	print "  <TR><TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$info[0] - $info[1]</TD>
				     <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$info[2]</TD>
        	        	     <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$info[3]</TD>
	                	     <TD ALIGN=LEFT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$info[4]</TD>
        		             <TD ALIGN=RIGHT bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$totalip</TD>
	        	             <TD ALIGN=CENTER bgcolor=$color><font color=$fcolor style=\"font-size\: 10pt\">$info[5]</TD></TR>\n";
                }
	@prevend = split(/\./, $info[1]);
        @prevstart = split(/\./, $info[0]);
        
	$first = "no";
        $fcolor = "black";
}

sub sorted_by{
  my($a1,$a2) = split(" ",$a);
  my($b1,$b2) = split(" ", $b);
  my($oct1, $oct2, $oct3, $oct4) = split(/\./,$a1);
  my($oct1_b, $oct2_b, $oct3_b, $oct4_b) = split(/\./,$b1);

  $oct1 <=> $oct1_b
  or
  $oct2 <=> $oct2_b
  or
  $oct3 <=> $oct3_b
  or
  $oct4 <=> $oct4_b;
}

# Return a DBI handle to the database
sub conndb
        {
        my $db_connect_string;
        if ($db{backend} eq "mysql")
                { $db_connect_string = "dbi:mysql:database=$db{name}" }
        elsif ($db{backend} eq "postgres")
                { $db_connect_string = "dbi:Pg:dbname=$db{name}" }
        else
                { return }
        if ($db{host})
                { $db_connect_string .= ";host=$db{host}" }
        return DBI->connect($db_connect_string, $db{user}, $db{password}, { RaiseError => $db{raiseerror}, AutoCommit => $db{autocommit} })
        }

