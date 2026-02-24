#!/usr/bin/perl

use CGI ':standard';
use CGI::Carp qw/fatalsToBrowser/;
use strict;
use warnings;

# ============================================================
# Configuration flags
# ============================================================
my $pdhcp  = 1;
my $popen  = 1;
my $perror = 1;
my $pissue = 1;
my $proute = 1;

# ============================================================
# DNS lookup — pull all netn records from allina.com zone
# ============================================================
my @dns = `host -l allina.com | grep netn | grep "has address 1"`;
# Uncomment below to test against localhost:
# my @dns = `host -l allina.com localhost | grep netn | grep "has address 167.177"`;

my @data;
my %found;

foreach my $line (@dns) {
    $line =~ s/\.allina\.com//g;
    my @string   = split(" ", $line);
    my @hname    = split(/\-/, $string[0]);
    my @dns_octs = split(/\-/, $string[0]);
    my @start_octs = split(/\./, $string[3]);

    if ($dns_octs[5] =~ m/\d/ && $dns_octs[6] =~ m/\d/) {
        my $dns_subnet = "255.255.$dns_octs[5].$dns_octs[6]";
        my ($end_octs3, $end_octs4) = ("", "");

        my %mask_map = (
            "255.255.255.255" => [0,   0],
            "255.255.255.254" => [0,   1],
            "255.255.255.252" => [0,   3],
            "255.255.255.248" => [0,   7],
            "255.255.255.240" => [0,  15],
            "255.255.255.224" => [0,  31],
            "255.255.255.192" => [0,  63],
            "255.255.255.128" => [0, 127],
            "255.255.255.0"   => [0, 255],
            "255.255.254.0"   => [1, 255],
            "255.255.252.0"   => [3, 255],
            "255.255.248.0"   => [7, 255],
            "255.255.240.0"   => [15, 255],
            "255.255.224.0"   => [31, 255],
            "255.255.192.0"   => [63, 255],
            "255.255.128.0"   => [127, 255],
            "255.255.0.0"     => [255, 255],
        );

        if (exists $mask_map{$dns_subnet}) {
            $end_octs3 = $start_octs[2] + $mask_map{$dns_subnet}[0];
            $end_octs4 = $start_octs[3] + $mask_map{$dns_subnet}[1];
        }

        if ($end_octs3 ne "" && $end_octs4 ne "") {
            if ($dns_octs[8] =~ m/\d/ && $dns_octs[9] =~ m/\d/) {
                push @data, "$string[3] - $start_octs[0].$start_octs[1].$end_octs3.$end_octs4 - $dns_subnet - $start_octs[0].$start_octs[1].$dns_octs[8].$dns_octs[9] - $string[0]\n";
            } else {
                push @data, "$string[3] - $start_octs[0].$start_octs[1].$end_octs3.$end_octs4 - $dns_subnet - UNKNOWN - $string[0]\n";
            }
            $found{$string[3]} = 1;
        }
    } else {
        push @data, "$string[3] - UNKNOWN - UNKNOWN - UNKNOWN - $string[0]\n";
        $found{$string[3]} = 1;
    }
}

# Sort by IP address
@data = sort {
    my ($a1) = split(" ", $a);
    my ($b1) = split(" ", $b);
    my @oa = split(/\./, $a1);
    my @ob = split(/\./, $b1);
    $oa[0] <=> $ob[0] || $oa[1] <=> $ob[1] || $oa[2] <=> $ob[2] || $oa[3] <=> $ob[3];
} @data;

# ============================================================
# Subnet -> total IPs map
# ============================================================
my %subnet_total = (
    "255.255.255.255" => 1,    "255.255.255.254" => 2,
    "255.255.255.252" => 3,    "255.255.255.248" => 7,
    "255.255.255.240" => 15,   "255.255.255.224" => 31,
    "255.255.255.192" => 63,   "255.255.255.128" => 127,
    "255.255.255.0"   => 255,  "255.255.254.0"   => 511,
    "255.255.252.0"   => 1023, "255.255.248.0"   => 2047,
    "255.255.240.0"   => 4095, "255.255.224.0"   => 8191,
    "255.255.192.0"   => 16383,"255.255.128.0"   => 32767,
    "255.255.0.0"     => 65535,"255.254.0.0"     => 131071,
    "255.252.0.0"     => 262143,"255.248.0.0"    => 524287,
    "255.240.0.0"     => 1048575,"255.224.0.0"   => 2097151,
    "255.192.0.0"     => 4194303,"255.0.0.0"     => 8388607,
);

# ============================================================
# Build JavaScript data array and collect filter sets
# ============================================================
my @js_rows;
my %site_set;
my %vlan_set;
my %desc_kw_set;

my $first    = "yes";
my @prevend  = ();
my @prevstart= ();

foreach my $entry (@data) {
    my @info   = split(/ \- /, $entry);
    chomp $info[-1];

    my @start  = split(/\./, $info[0]);
    my @end    = split(/\./, $info[1]);
    my $subnet = $info[2] || "";
    my $gw     = $info[3] || "";
    my $desc   = $info[4] || "";
    chomp $desc;

    my $totalip = $subnet_total{$subnet} || "";

    # --- Parse description for site, vlan, desc label ---
    # Pattern: netn-{env}-{site}-{o3}-{o4}-{m1}-{m2}-{vlan}-{e3}-{e4}-{label}
    my @dparts  = split(/-/, $desc);
    my $site    = $dparts[2] || "";
    my $vlan    = $dparts[7] || "";
    (my $label  = join(" ", @dparts[10..$#dparts])) =~ s/_/ /g;
    $label =~ s/^\s+|\s+$//g;

    $site_set{uc($site)} = 1 if $site;
    $vlan_set{$vlan}     = 1 if $vlan && $vlan =~ /^\d+$/;
    foreach my $w (split(/\s+/, lc($label))) {
        $desc_kw_set{$w} = 1 if length($w) > 3;
    }

    # --- Detect open space before this entry ---
    if ($popen && $first ne "yes" && $prevend[0] ne "UNKNOWN") {
        unless ($start[0] eq $prevstart[0] && $start[1] eq $prevstart[1] &&
                $start[2] eq $prevstart[2] && $start[3] eq $prevstart[3]) {

            my $free;
            if ($start[1] eq $prevend[1]) {
                if ($start[2] eq $prevend[2]) {
                    $free = ($start[3] - $prevend[3] - 1);
                } else {
                    $free = ($start[2] - $prevend[2] - 1) * 256 + (255 - $prevend[3]) + $start[3];
                }
            } else {
                $free = ($start[1] - $prevend[1]) * 65536 +
                        ($start[2] - $prevend[2]) * 256  +
                        ($start[3] - $prevend[3] - 1);
            }

            if (defined $free && $free != 0) {
                # Calculate open range start
                my ($n1,$n2,$n3) = ($prevend[1], $prevend[2], $prevend[3]+1);
                if ($n3 == 256) { $n2++; $n3 = 0; }
                if ($n2 == 256) { $n1++; $n2 = 0; }

                # Calculate open range end
                my ($e1,$e2,$e3) = ($start[1], $start[2], $start[3]-1);
                if ($e3 == -1) { $e2--; $e3 = 255; }
                if ($e2 == -1) { $e1--; $e2 = 255; }

                my $type    = ($free < 0) ? "error" : "open";
                my $comment = ($free < 0) ? "Overlapping subnet" : "";
                my $free_str= ($free < 0) ? "Error" : "$free Hosts open";
                my $open_net= "$start[0].$n1.$n2.$n3";
                my $open_end= "$start[0].$e1.$e2.$e3";

                push @js_rows, {
                    net     => $open_net,
                    end     => $open_end,
                    subnet  => $free_str,
                    gw      => "",
                    desc    => "",
                    label   => "",
                    site    => "",
                    vlan    => "",
                    usable  => "",
                    comment => $comment,
                    type    => $type,
                };
            }
        }
    }

    # --- Push the actual subnet row ---
    push @js_rows, {
        net     => $info[0],
        end     => $info[1],
        subnet  => $subnet,
        gw      => $gw,
        desc    => $desc,
        label   => $label,
        site    => uc($site),
        vlan    => $vlan,
        usable  => $totalip,
        comment => "",
        type    => "normal",
    };

    @prevend   = @end;
    @prevstart = @start;
    $first     = "no";
}

# ============================================================
# Emit HTML
# ============================================================
print header;

# Build JS arrays
my $js_data = "[\n";
foreach my $r (@js_rows) {
    (my $desc_js  = $r->{desc})  =~ s/\\/\\\\/g; $desc_js  =~ s/'/\\'/g;
    (my $label_js = $r->{label}) =~ s/\\/\\\\/g; $label_js =~ s/'/\\'/g;
    (my $gw_js    = $r->{gw})    =~ s/'/\\'/g;
    $js_data .= "  {net:'$r->{net}',end:'$r->{end}',subnet:'$r->{subnet}',gw:'$gw_js',"
              . "desc:'$desc_js',label:'$label_js',site:'$r->{site}',vlan:'$r->{vlan}',"
              . "usable:'$r->{usable}',comment:'$r->{comment}',type:'$r->{type}'},\n";
}
$js_data .= "]";

my $sites_js = join(",", map { "'$_'" } sort keys %site_set);
my $vlans_js = join(",", map { "'$_'" } sort { $a <=> $b } keys %vlan_set);
my $kws_js   = join(",", map { "'$_'" } sort keys %desc_kw_set);

print <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>ANS - Subnet Breakdown</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;500;600&family=JetBrains+Mono:wght\@400;600&display=swap" rel="stylesheet">
<style>
  :root {
    --bg:         #f0f4f9;
    --surface:    #ffffff;
    --surface2:   #e8f0fb;
    --border:     #c8d8ee;
    --navy:       #003366;
    --navy2:      #004a99;
    --accent:     #0066cc;
    --accent2:    #0099aa;
    --text:       #1a2a3a;
    --text-dim:   #5a7090;
    --open-bg:    #fff0f3;
    --open-text:  #cc2244;
    --open-border:#f0b8c4;
    --err-bg:     #fff8e8;
    --err-text:   #aa6600;
    --row-alt:    #f7faff;
    --header-bg:  #003366;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Inter', sans-serif;
    font-size: 13px;
    min-height: 100vh;
  }

  /* ---- Header ---- */
  header {
    background: linear-gradient(135deg, #002244 0%, #003d7a 60%, #005599 100%);
    border-bottom: 3px solid #4499dd;
    padding: 18px 28px 14px;
    position: sticky;
    top: 0;
    z-index: 100;
    box-shadow: 0 3px 16px rgba(0,51,102,0.25);
  }

  .header-top {
    display: flex;
    align-items: baseline;
    gap: 14px;
  }

  .header-title {
    font-family: 'JetBrains Mono', monospace;
    font-size: 20px;
    font-weight: 600;
    color: #ffffff;
    letter-spacing: 1px;
  }

  .header-sub {
    font-size: 12px;
    color: #88bbee;
    letter-spacing: 1px;
    font-family: 'JetBrains Mono', monospace;
  }

  /* ---- Filter bar ---- */
  .controls {
    display: flex;
    gap: 14px;
    margin-top: 12px;
    flex-wrap: wrap;
    align-items: flex-end;
  }

  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .filter-group label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #88bbee;
    font-family: 'JetBrains Mono', monospace;
  }

  select {
    background: rgba(255,255,255,0.12);
    border: 1px solid rgba(255,255,255,0.25);
    color: #ffffff;
    padding: 5px 26px 5px 9px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    border-radius: 5px;
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath d='M0 0l5 6 5-6z' fill='%2388bbee'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
    min-width: 150px;
    transition: border-color 0.2s, background 0.2s;
  }

  select option { background: #003366; color: #fff; }

  select:hover, select:focus {
    border-color: rgba(255,255,255,0.6);
    background-color: rgba(255,255,255,0.2);
    outline: none;
  }

  .search-group {
    display: flex;
    flex-direction: column;
    gap: 3px;
    flex: 1;
    min-width: 180px;
  }

  .search-group input {
    background: rgba(255,255,255,0.12);
    border: 1px solid rgba(255,255,255,0.25);
    color: #ffffff;
    padding: 5px 9px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    border-radius: 5px;
    transition: border-color 0.2s;
  }

  .search-group input::placeholder { color: #6699bb; }
  .search-group input:focus { outline: none; border-color: rgba(255,255,255,0.6); }

  .reset-btn {
    background: rgba(255,255,255,0.1);
    border: 1px solid rgba(255,255,255,0.3);
    color: #aaccee;
    padding: 5px 14px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    border-radius: 5px;
    cursor: pointer;
    letter-spacing: 0.5px;
    transition: all 0.2s;
    align-self: flex-end;
  }

  .reset-btn:hover { background: rgba(255,255,255,0.22); color: #fff; }

  /* ---- Stats bar ---- */
  .stats {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--text-dim);
    padding: 7px 28px;
    background: var(--surface2);
    border-bottom: 1px solid var(--border);
    display: flex;
    gap: 18px;
  }

  .stats .badge {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }

  .stats .num { color: var(--accent); font-weight: 600; }
  .stats .open-num { color: var(--open-text); font-weight: 600; }

  /* ---- Table ---- */
  .table-wrap {
    padding: 0;
    overflow-x: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
  }

  thead {
    position: sticky;
    top: 0;
    z-index: 50;
  }

  thead th {
    background: #e0eaf8;
    color: var(--navy);
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    padding: 9px 12px;
    text-align: left;
    border-bottom: 2px solid #a8c4e4;
    border-right: 1px solid #c8d8ee;
    white-space: nowrap;
    cursor: pointer;
    user-select: none;
    font-weight: 600;
  }

  thead th:hover { background: #ccddf5; }
  thead th.sorted { color: var(--accent2); background: #ccddf5; }

  tbody tr { border-bottom: 1px solid var(--border); transition: background 0.1s; }
  tbody tr:nth-child(even).row-normal { background: var(--row-alt); }
  tbody tr:nth-child(odd).row-normal  { background: var(--surface); }
  tbody tr.row-normal:hover  { background: #ddeeff !important; }

  tbody tr.row-open   { background: var(--open-bg); }
  tbody tr.row-open:hover { background: #ffe0e8 !important; }
  tbody tr.row-error  { background: var(--err-bg); }
  tbody tr.row-error:hover { background: #ffeebb !important; }

  td {
    padding: 6px 12px;
    white-space: nowrap;
    border-right: 1px solid var(--border);
    color: var(--text);
  }

  .td-network  { font-weight: 500; color: #003d7a; }
  .td-subnet   { color: var(--text-dim); }
  .td-gateway  { color: #006633; }
  .td-desc     { max-width: 440px; overflow: hidden; text-overflow: ellipsis; color: var(--text); }
  .td-usable   { text-align: right; color: var(--accent); font-weight: 600; }
  .td-comment  { color: var(--text-dim); font-style: italic; }

  .tag-site {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    margin-right: 5px;
    border: 1px solid transparent;
  }

  .tag-vlan {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    background: #e0eeff;
    color: #0044aa;
    border: 1px solid #b0ccee;
    margin-right: 5px;
  }

  /* Site colors - bright on light bg */
  .site-UTY { background:#fff3e0; border-color:#ffcc88; color:#b85c00; }
  .site-STC { background:#f0e8ff; border-color:#ccaaee; color:#6600aa; }
  .site-ANW { background:#e0fff4; border-color:#88ddbb; color:#006644; }
  .site-MCY { background:#ffe8e8; border-color:#ffaaaa; color:#aa0000; }
  .site-UNI { background:#e0f4ff; border-color:#88ccee; color:#005588; }
  .site-CAM { background:#fffce0; border-color:#eedd88; color:#886600; }
  .site-REM { background:#f4e0ff; border-color:#ddaaff; color:#660088; }
  .site-CRM { background:#e8ffee; border-color:#88dd99; color:#006622; }
  .site-MP2 { background:#e8f0ff; border-color:#99aadd; color:#223388; }

  .open-label   { color: var(--open-text) !important; font-weight: 600; }
  .error-label  { color: var(--err-text)  !important; font-weight: 600; }

  .hidden { display: none !important; }

  /* ---- Legend ---- */
  .legend {
    display: flex;
    gap: 18px;
    padding: 8px 28px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    font-size: 11px;
    color: var(--text-dim);
    flex-wrap: wrap;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .swatch {
    width: 12px; height: 12px;
    border-radius: 2px;
    border: 1px solid rgba(0,0,0,0.15);
    display: inline-block;
  }
</style>
</head>
<body>

<header>
  <div class="header-top">
    <div class="header-title">ANS &mdash; Subnet Breakdown</div>
    <div class="header-sub">167.177 Network Space</div>
  </div>
  <div class="controls">
    <div class="filter-group">
      <label>&#9656; Site</label>
      <select id="filterSite">
        <option value="">All Sites</option>
      </select>
    </div>
    <div class="filter-group">
      <label>&#9656; VLAN</label>
      <select id="filterVlan">
        <option value="">All VLANs</option>
      </select>
    </div>
    <div class="filter-group">
      <label>&#9656; Description keyword</label>
      <select id="filterDesc">
        <option value="">All Descriptions</option>
      </select>
    </div>
    <div class="search-group">
      <label>&#9656; Free text search</label>
      <input type="text" id="searchText" placeholder="Search any field&hellip;">
    </div>
    <button class="reset-btn" onclick="resetFilters()">&times; Reset</button>
  </div>
</header>

<div class="stats">
  <span class="badge">Showing <span class="num" id="visCount">0</span> of <span class="num" id="totalCount">0</span> subnets</span>
  <span class="badge">Open gaps: <span class="open-num" id="openCount">0</span></span>
</div>

<div class="legend">
  <span class="legend-item"><span class="swatch" style="background:#ffffff;border-color:#c8d8ee"></span>Allocated subnet</span>
  <span class="legend-item"><span class="swatch" style="background:#fff0f3;border-color:#f0b8c4"></span>Open / unallocated space</span>
  <span class="legend-item"><span class="swatch" style="background:#fff8e8;border-color:#eeddaa"></span>Overlapping / error</span>
</div>

<div class="table-wrap">
  <table id="mainTable">
    <thead>
      <tr>
        <th onclick="sortTable(0)" title="Sort by network">Network Range</th>
        <th onclick="sortTable(1)" title="Sort by subnet">Subnet Mask</th>
        <th onclick="sortTable(2)">Gateway</th>
        <th onclick="sortTable(3)">Description</th>
        <th onclick="sortTable(4)">Usable</th>
        <th>Comment</th>
      </tr>
    </thead>
    <tbody id="tbody"></tbody>
  </table>
</div>

<script>
const rawData = $js_data;

// ---- Populate dropdowns from Perl-generated sets ----
const allSites = [$sites_js];
const allVlans = [$vlans_js];
const allKws   = [$kws_js];

function addOptions(selId, values) {
  const sel = document.getElementById(selId);
  values.forEach(v => {
    const o = document.createElement('option');
    o.value = v; o.textContent = v;
    sel.appendChild(o);
  });
}
addOptions('filterSite', allSites);
addOptions('filterVlan', allVlans);
addOptions('filterDesc', allKws);

// ---- Build table rows ----
const tbody = document.getElementById('tbody');

rawData.forEach((r, i) => {
  const tr = document.createElement('tr');

  if (r.type === 'open') {
    tr.className = 'row-open';
  } else if (r.type === 'error') {
    tr.className = 'row-error';
  } else {
    tr.className = 'row-normal';
  }

  // data attrs for filtering
  tr.dataset.site = r.site.toLowerCase();
  tr.dataset.vlan = r.vlan;
  tr.dataset.desc = r.label.toLowerCase();
  tr.dataset.all  = (r.net+' '+r.end+' '+r.subnet+' '+r.gw+' '+r.desc+' '+r.comment).toLowerCase();
  tr.dataset.type = r.type;

  if (r.type === 'open' || r.type === 'error') {
    const cls = r.type === 'error' ? 'error-label' : 'open-label';
    tr.innerHTML =
      '<td class="td-network ' + cls + '">' + r.net + ' &mdash; ' + r.end + '</td>' +
      '<td class="' + cls + '">' + r.subnet + '</td>' +
      '<td></td>' +
      '<td></td>' +
      '<td></td>' +
      '<td class="td-comment">' + r.comment + '</td>';
  } else {
    const siteTag = r.site
      ? '<span class="tag-site site-' + r.site + '">' + r.site + '</span>'
      : '';
    const vlanTag = r.vlan
      ? '<span class="tag-vlan">VLAN&nbsp;' + r.vlan + '</span>'
      : '';
    tr.innerHTML =
      '<td class="td-network">' + r.net + ' &mdash; ' + r.end + '</td>' +
      '<td class="td-subnet">' + r.subnet + '</td>' +
      '<td class="td-gateway">' + r.gw + '</td>' +
      '<td class="td-desc">' + siteTag + vlanTag + (r.label || r.desc) + '</td>' +
      '<td class="td-usable">' + r.usable + '</td>' +
      '<td class="td-comment">' + r.comment + '</td>';
  }

  tbody.appendChild(tr);
});

updateStats();

// ---- Filtering ----
function applyFilters() {
  const site = document.getElementById('filterSite').value.toLowerCase();
  const vlan = document.getElementById('filterVlan').value;
  const desc = document.getElementById('filterDesc').value.toLowerCase();
  const text = document.getElementById('searchText').value.toLowerCase().trim();

  let vis = 0, opens = 0;
  document.querySelectorAll('#tbody tr').forEach(tr => {
    // open/error rows: only show if no specific filters active
    const isSpecial = tr.dataset.type === 'open' || tr.dataset.type === 'error';
    let show;
    if (isSpecial) {
      show = !site && !vlan && !desc && !text;
    } else {
      show =
        (!site || tr.dataset.site === site) &&
        (!vlan || tr.dataset.vlan === vlan) &&
        (!desc || tr.dataset.desc.includes(desc)) &&
        (!text || tr.dataset.all.includes(text));
    }
    tr.classList.toggle('hidden', !show);
    if (show) {
      vis++;
      if (tr.dataset.type === 'open') opens++;
    }
  });
  document.getElementById('visCount').textContent = vis;
  document.getElementById('openCount').textContent = opens;
}

function updateStats() {
  const total = document.querySelectorAll('#tbody tr.row-normal').length;
  const opens = document.querySelectorAll('#tbody tr.row-open').length;
  document.getElementById('totalCount').textContent = total;
  document.getElementById('visCount').textContent   = total + opens;
  document.getElementById('openCount').textContent  = opens;
}

function resetFilters() {
  ['filterSite','filterVlan','filterDesc'].forEach(id => document.getElementById(id).value = '');
  document.getElementById('searchText').value = '';
  document.querySelectorAll('#tbody tr').forEach(tr => tr.classList.remove('hidden'));
  updateStats();
}

['filterSite','filterVlan','filterDesc'].forEach(id => {
  document.getElementById(id).addEventListener('change', applyFilters);
});
document.getElementById('searchText').addEventListener('input', applyFilters);

// ---- Sorting ----
let sortDir = {};
function sortTable(col) {
  const rows = [...document.querySelectorAll('#tbody tr')];
  const dir  = (sortDir[col] = !sortDir[col]);

  rows.sort((a, b) => {
    const av = a.cells[col] ? a.cells[col].textContent.trim() : '';
    const bv = b.cells[col] ? b.cells[col].textContent.trim() : '';
    const ipA = av.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)/);
    const ipB = bv.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)/);
    if (ipA && ipB) {
      for (let i = 1; i <= 4; i++) {
        const d = parseInt(ipA[i]) - parseInt(ipB[i]);
        if (d !== 0) return dir ? d : -d;
      }
      return 0;
    }
    return dir ? av.localeCompare(bv) : bv.localeCompare(av);
  });

  rows.forEach(r => tbody.appendChild(r));

  document.querySelectorAll('thead th').forEach((th, i) => {
    th.classList.toggle('sorted', i === col);
  });
}
</script>
</body>
</html>
HTML
