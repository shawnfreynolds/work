#!/usr/bin/perl

use CGI ':standard';
use CGI::Carp qw/fatalsToBrowser/;
use strict;
use warnings;

# ============================================================
# Configuration flags
# ============================================================
my $popen  = 1;
my $perror = 1;

# ============================================================
# DNS lookup — pull all netn records, all address ranges
# ============================================================
my @dns = `host -l allina.com | grep netn | grep "has address 1"`;
# Uncomment to test against localhost:
# my @dns = `host -l allina.com localhost | grep netn | grep "has address 1"`;

my @data;
my %found;

foreach my $line (@dns) {
    $line =~ s/\.allina\.com//g;
    chomp $line;
    my @string     = split(" ", $line);
    my @dns_octs   = split(/\-/, $string[0]);
    my @start_octs = split(/\./, $string[3]);

    if (defined $dns_octs[5] && $dns_octs[5] =~ m/^\d+$/ &&
        defined $dns_octs[6] && $dns_octs[6] =~ m/^\d+$/) {

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
            my $gw;
            if (defined $dns_octs[8] && $dns_octs[8] =~ m/^\d+$/ &&
                defined $dns_octs[9] && $dns_octs[9] =~ m/^\d+$/) {
                $gw = "$start_octs[0].$start_octs[1].$dns_octs[8].$dns_octs[9]";
            } else {
                $gw = "UNKNOWN";
            }
            push @data, "$string[3] - $start_octs[0].$start_octs[1].$end_octs3.$end_octs4 - $dns_subnet - $gw - $string[0]\n";
            $found{$string[3]} = 1;
        }
    } else {
        push @data, "$string[3] - UNKNOWN - UNKNOWN - UNKNOWN - $string[0]\n";
        $found{$string[3]} = 1;
    }
}

# ============================================================
# Sort by IP address numerically
# ============================================================
@data = sort {
    my ($a1) = split(" ", $a);
    my ($b1) = split(" ", $b);
    my @oa = split(/\./, $a1);
    my @ob = split(/\./, $b1);
    $oa[0] <=> $ob[0] || $oa[1] <=> $ob[1] || $oa[2] <=> $ob[2] || $oa[3] <=> $ob[3];
} @data;

# ============================================================
# Subnet -> usable hosts map
# ============================================================
my %subnet_total = (
    "255.255.255.255" => 1,       "255.255.255.254" => 2,
    "255.255.255.252" => 3,       "255.255.255.248" => 7,
    "255.255.255.240" => 15,      "255.255.255.224" => 31,
    "255.255.255.192" => 63,      "255.255.255.128" => 127,
    "255.255.255.0"   => 255,     "255.255.254.0"   => 511,
    "255.255.252.0"   => 1023,    "255.255.248.0"   => 2047,
    "255.255.240.0"   => 4095,    "255.255.224.0"   => 8191,
    "255.255.192.0"   => 16383,   "255.255.128.0"   => 32767,
    "255.255.0.0"     => 65535,   "255.254.0.0"     => 131071,
    "255.252.0.0"     => 262143,  "255.248.0.0"     => 524287,
    "255.240.0.0"     => 1048575, "255.224.0.0"     => 2097151,
    "255.192.0.0"     => 4194303, "255.0.0.0"       => 8388607,
);

# ============================================================
# Build JS data rows + collect dropdown values
# ============================================================
my @js_rows;
my %site_set;
my %vlan_set;

my $first      = "yes";
my @prevend    = ();
my @prevstart  = ();
my $prev_range = "";

foreach my $entry (@data) {
    my @info = split(/ \- /, $entry);
    chomp $info[-1];

    my @start  = split(/\./, $info[0]);
    my @end    = split(/\./, $info[1]);
    my $subnet = $info[2] || "";
    my $gw     = $info[3] || "";
    my $desc   = $info[4] || "";   # full netn string kept as-is
    chomp $desc;

    my $totalip = $subnet_total{$subnet} || "";

    # --- Determine network range bucket ---
    my $range = "Other";
    if    ($start[0] == 10)                              { $range = "10.0.0.0/8";      }
    elsif ($start[0] == 167 && $start[1] == 177)         { $range = "167.177.0.0/16";  }

    # --- Parse description fields (split on '-') ---
    # netn - {env} - {site} - {o3} - {o4} - {mask3} - {mask4} - {vlan} - {e3} - {e4} - {comment...}
    # idx:   0       1        2       3       4          5         6        7      8      9    10+
    my @dparts = split(/\-/, $desc);
    my $site   = (defined $dparts[2]) ? $dparts[2] : "";
    my $vlan   = (defined $dparts[7]) ? $dparts[7] : "";

    # Comment = everything from index 10 onward, joined by '-', underscores become spaces
    my $comment = "";
    if (scalar @dparts > 10) {
        $comment = join("-", @dparts[10..$#dparts]);
        $comment =~ s/_/ /g;
    }

    $site_set{uc($site)} = 1 if $site;
    $vlan_set{$vlan}     = 1 if $vlan && $vlan =~ /^\d+$/;

    # --- Detect open/gap space before this entry (within same range only) ---
    if ($popen && $first ne "yes"
        && scalar @prevend && $prevend[0] ne "UNKNOWN"
        && $prev_range eq $range) {

        unless ($start[0] == $prevstart[0] && $start[1] == $prevstart[1] &&
                $start[2] == $prevstart[2] && $start[3] == $prevstart[3]) {

            my $free;
            if ($start[1] == $prevend[1]) {
                if ($start[2] == $prevend[2]) {
                    $free = $start[3] - $prevend[3] - 1;
                } else {
                    $free = ($start[2] - $prevend[2] - 1) * 256
                          + (255 - $prevend[3]) + $start[3];
                }
            } else {
                $free = ($start[1] - $prevend[1]) * 65536
                      + ($start[2] - $prevend[2]) * 256
                      + ($start[3] - $prevend[3] - 1);
            }

            if (defined $free && $free != 0) {
                # Open range start
                my ($n1,$n2,$n3) = ($prevend[1], $prevend[2], $prevend[3]+1);
                if ($n3 == 256) { $n2++; $n3 = 0; }
                if ($n2 == 256) { $n1++; $n2 = 0; }

                # Open range end
                my ($e1,$e2,$e3) = ($start[1], $start[2], $start[3]-1);
                if ($e3 == -1) { $e2--; $e3 = 255; }
                if ($e2 == -1) { $e1--; $e2 = 255; }

                my $type     = ($free < 0) ? "error" : "open";
                my $err_comm = ($free < 0) ? "Overlapping subnet" : "";
                my $free_str = ($free < 0) ? "Error" : "$free hosts open";

                push @js_rows, {
                    net     => "$start[0].$n1.$n2.$n3",
                    end     => "$start[0].$e1.$e2.$e3",
                    subnet  => $free_str,
                    gw      => "",
                    desc    => "",
                    site    => "",
                    vlan    => "",
                    usable  => "",
                    comment => $err_comm,
                    range   => $range,
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
        site    => uc($site),
        vlan    => $vlan,
        usable  => $totalip,
        comment => $comment,
        range   => $range,
        type    => "normal",
    };

    @prevend    = @end;
    @prevstart  = @start;
    $prev_range = $range;
    $first      = "no";
}

# ============================================================
# Emit HTML
# ============================================================
print header;

# Escape and serialize rows to JS
my $js_data = "[\n";
foreach my $r (@js_rows) {
    for my $k (qw(net end subnet gw desc site vlan usable comment range type)) {
        $r->{$k} //= "";
        $r->{$k} =~ s/\\/\\\\/g;
        $r->{$k} =~ s/'/\\'/g;
        $r->{$k} =~ s/\n//g;
    }
    $js_data .= "  {net:'$r->{net}',end:'$r->{end}',subnet:'$r->{subnet}',"
             .  "gw:'$r->{gw}',desc:'$r->{desc}',site:'$r->{site}',"
             .  "vlan:'$r->{vlan}',usable:'$r->{usable}',comment:'$r->{comment}',"
             .  "range:'$r->{range}',type:'$r->{type}'},\n";
}
$js_data .= "]";

my $sites_js = join(",", map { "'$_'" } sort keys %site_set);
my $vlans_js = join(",", map { "'$_'" } sort { $a <=> $b } keys %vlan_set);

print <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>ANS - Subnet Breakdown</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;500;600&family=JetBrains+Mono:wght\@400;600&display=swap" rel="stylesheet">
<style>
  :root {
    --bg:        #f0f4f9;
    --surface:   #ffffff;
    --surface2:  #e8f0fb;
    --border:    #c8d8ee;
    --navy:      #003366;
    --accent:    #0066cc;
    --accent2:   #0099aa;
    --text:      #1a2a3a;
    --text-dim:  #5a7090;
    --open-bg:   #fff0f3;
    --open-text: #cc2244;
    --err-bg:    #fff8e8;
    --err-text:  #aa6600;
    --row-alt:   #f5f8ff;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Inter', sans-serif;
    font-size: 13px;
    min-height: 100vh;
  }

  header {
    background: linear-gradient(135deg, #002244 0%, #003d7a 60%, #005599 100%);
    border-bottom: 3px solid #4499dd;
    padding: 14px 24px 12px;
    position: sticky;
    top: 0;
    z-index: 100;
    box-shadow: 0 3px 16px rgba(0,51,102,0.3);
  }

  .header-top {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 10px;
  }

  .header-title {
    font-family: 'JetBrains Mono', monospace;
    font-size: 18px;
    font-weight: 600;
    color: #fff;
    letter-spacing: 1px;
  }

  .header-sub {
    font-size: 11px;
    color: #88bbee;
    font-family: 'JetBrains Mono', monospace;
    letter-spacing: 1px;
  }

  .controls {
    display: flex;
    gap: 10px;
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
    letter-spacing: 1.1px;
    color: #88bbee;
    font-family: 'JetBrains Mono', monospace;
    white-space: nowrap;
  }

  select, .ctrl-input {
    background: rgba(255,255,255,0.12);
    border: 1px solid rgba(255,255,255,0.28);
    color: #ffffff;
    padding: 5px 10px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
    border-radius: 4px;
    height: 30px;
    transition: border-color 0.15s, background 0.15s;
  }

  select {
    padding-right: 26px;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath d='M0 0l5 6 5-6z' fill='%2388bbee'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 7px center;
    cursor: pointer;
    min-width: 130px;
  }

  select option { background: #00336e; color: #fff; }

  select:hover, select:focus,
  .ctrl-input:hover, .ctrl-input:focus {
    border-color: rgba(255,255,255,0.65);
    background-color: rgba(255,255,255,0.18);
    outline: none;
  }

  .ctrl-input::placeholder { color: #6699bb; }
  .ctrl-input.wide { min-width: 200px; flex: 1; }

  .ctrl-input.regex-ok    { border-color: rgba(0,200,100,0.7) !important; }
  .ctrl-input.regex-error { border-color: rgba(220,50,50,0.9) !important; background-color: rgba(255,180,180,0.15) !important; }

  .reset-btn {
    background: rgba(255,255,255,0.1);
    border: 1px solid rgba(255,255,255,0.3);
    color: #aaccee;
    padding: 0 14px;
    height: 30px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    border-radius: 4px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s;
    align-self: flex-end;
  }

  .reset-btn:hover { background: rgba(255,255,255,0.22); color: #fff; border-color: rgba(255,255,255,0.6); }

  .stats {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--text-dim);
    padding: 6px 24px;
    background: var(--surface2);
    border-bottom: 1px solid var(--border);
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
  }

  .stats .num      { color: var(--accent);    font-weight: 600; }
  .stats .open-num { color: var(--open-text); font-weight: 600; }

  .legend {
    display: flex;
    gap: 20px;
    padding: 5px 24px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    font-size: 11px;
    color: var(--text-dim);
    flex-wrap: wrap;
  }

  .legend-item { display: flex; align-items: center; gap: 6px; }

  .swatch {
    width: 11px; height: 11px;
    border-radius: 2px;
    border: 1px solid rgba(0,0,0,0.18);
    flex-shrink: 0;
  }

  .table-wrap { overflow-x: auto; }

  table {
    width: 100%;
    border-collapse: collapse;
    font-family: 'JetBrains Mono', monospace;
    font-size: 12px;
  }

  thead th {
    background: #dce8f8;
    color: var(--navy);
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 1.1px;
    padding: 8px 12px;
    text-align: left;
    border-bottom: 2px solid #a8c4e4;
    border-right: 1px solid #c0d4ec;
    white-space: nowrap;
    cursor: pointer;
    user-select: none;
    font-weight: 600;
    position: sticky;
    top: 0;
    z-index: 10;
  }

  thead th:hover  { background: #ccdaf5; }
  thead th.sorted { background: #c0d4f2; color: var(--accent2); }
  thead th::after { content: ' \25B5\25BF'; opacity: 0.3; font-size: 8px; }
  thead th.sorted-asc::after  { content: ' \25B4'; opacity: 1; }
  thead th.sorted-desc::after { content: ' \25BE'; opacity: 1; }

  tbody tr { border-bottom: 1px solid var(--border); transition: background 0.07s; }

  tbody tr.row-normal:nth-child(even) { background: var(--row-alt); }
  tbody tr.row-normal:nth-child(odd)  { background: var(--surface); }
  tbody tr.row-normal:hover           { background: #d8eaff !important; }
  tbody tr.row-open                   { background: var(--open-bg); }
  tbody tr.row-open:hover             { background: #ffe0e8 !important; }
  tbody tr.row-error                  { background: var(--err-bg); }
  tbody tr.row-error:hover            { background: #ffeebb !important; }

  td {
    padding: 5px 12px;
    white-space: nowrap;
    border-right: 1px solid var(--border);
  }

  .td-network { color: #003d7a; font-weight: 500; }
  .td-subnet  { color: var(--text-dim); }
  .td-gateway { color: #005533; }
  .td-desc    { color: var(--text); max-width: 500px; overflow: hidden; text-overflow: ellipsis; }
  .td-usable  { text-align: right; color: var(--accent); font-weight: 600; }
  .td-comment { color: #444; font-style: italic; max-width: 220px; overflow: hidden; text-overflow: ellipsis; }
  .td-range   { color: var(--text-dim); font-size: 11px; }

  .open-label  { color: var(--open-text) !important; font-weight: 600; }
  .error-label { color: var(--err-text)  !important; font-weight: 600; }

  .tag-site {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.7px;
    margin-right: 5px;
    border: 1px solid transparent;
    vertical-align: middle;
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
    vertical-align: middle;
  }

  /* Site tag palette */
  .site-UTY { background:#fff3e0; border-color:#ffcc88; color:#b85c00; }
  .site-STC { background:#f0e8ff; border-color:#ccaaee; color:#6600aa; }
  .site-ANW { background:#e0fff4; border-color:#88ddbb; color:#006644; }
  .site-MCY { background:#ffe8e8; border-color:#ffaaaa; color:#aa0000; }
  .site-UNI { background:#e0f4ff; border-color:#88ccee; color:#005588; }
  .site-CAM { background:#fffce0; border-color:#eedd88; color:#886600; }
  .site-REM { background:#f4e0ff; border-color:#ddaaff; color:#660088; }
  .site-CRM { background:#e8ffee; border-color:#88dd99; color:#006622; }
  .site-MP2 { background:#e8f0ff; border-color:#99aadd; color:#223388; }

  .hidden { display: none !important; }
</style>
</head>
<body>

<header>
  <div class="header-top">
    <div class="header-title">ANS &mdash; Subnet Breakdown</div>
    <div class="header-sub">All Network Ranges</div>
  </div>
  <div class="controls">

    <div class="filter-group">
      <label>Network Range</label>
      <select id="filterRange">
        <option value="">All Ranges</option>
        <option value="167.177.0.0/16">167.177.0.0 /16</option>
        <option value="10.0.0.0/8">10.0.0.0 /8</option>
        <option value="Other">Other</option>
      </select>
    </div>

    <div class="filter-group">
      <label>Site</label>
      <select id="filterSite">
        <option value="">All Sites</option>
      </select>
    </div>

    <div class="filter-group">
      <label>VLAN</label>
      <select id="filterVlan">
        <option value="">All VLANs</option>
      </select>
    </div>

    <div class="filter-group">
      <label>Comment (regex)</label>
      <input type="text" id="filterComment" class="ctrl-input" placeholder="e.g. dmz|citrix" title="Supports regular expressions">
    </div>

    <div class="filter-group" style="flex:1">
      <label>Search any field (regex)</label>
      <input type="text" id="searchText" class="ctrl-input wide" placeholder="e.g. scriptpro|heartbeat">
    </div>

    <button class="reset-btn" onclick="resetFilters()">&times;&nbsp;Reset</button>

  </div>
</header>

<div class="stats">
  <span>Showing <span class="num" id="visCount">0</span> of <span class="num" id="totalCount">0</span> allocated subnets</span>
  <span>Open gaps: <span class="open-num" id="openCount">0</span></span>
</div>

<div class="legend">
  <span class="legend-item"><span class="swatch" style="background:#fff;border-color:#c8d8ee"></span>Allocated subnet</span>
  <span class="legend-item"><span class="swatch" style="background:#fff0f3;border-color:#f0b8c4"></span>Open / unallocated</span>
  <span class="legend-item"><span class="swatch" style="background:#fff8e8;border-color:#eeddaa"></span>Overlapping / error</span>
</div>

<div class="table-wrap">
  <table id="mainTable">
    <thead>
      <tr>
        <th onclick="sortTable(0)">Network Range</th>
        <th onclick="sortTable(1)">Subnet Mask</th>
        <th onclick="sortTable(2)">Gateway</th>
        <th onclick="sortTable(3)">Description (DNS)</th>
        <th onclick="sortTable(4)">Usable</th>
        <th onclick="sortTable(5)">Comment</th>
        <th onclick="sortTable(6)">Range</th>
      </tr>
    </thead>
    <tbody id="tbody"></tbody>
  </table>
</div>

<script>
const rawData = $js_data;

const allSites = [$sites_js];
const allVlans = [$vlans_js];

function addOpts(id, vals) {
  const sel = document.getElementById(id);
  vals.forEach(v => {
    const o = document.createElement('option');
    o.value = v; o.textContent = v; sel.appendChild(o);
  });
}
addOpts('filterSite', allSites);
addOpts('filterVlan', allVlans);

// ---- HTML escape ----
function esc(s) {
  return String(s || '')
    .replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ---- Build rows ----
const tbody = document.getElementById('tbody');

rawData.forEach(r => {
  const tr = document.createElement('tr');
  tr.className = r.type === 'open'  ? 'row-open'
               : r.type === 'error' ? 'row-error'
               : 'row-normal';

  tr.dataset.site    = r.site.toLowerCase();
  tr.dataset.vlan    = r.vlan;
  tr.dataset.comment = r.comment.toLowerCase();
  tr.dataset.range   = r.range;
  tr.dataset.type    = r.type;
  tr.dataset.all     = [r.net,r.end,r.subnet,r.gw,r.desc,r.comment,r.range].join(' ').toLowerCase();

  if (r.type === 'open' || r.type === 'error') {
    const cls = r.type === 'error' ? 'error-label' : 'open-label';
    tr.innerHTML =
      '<td class="td-network ' + cls + '">' + esc(r.net) + ' &mdash; ' + esc(r.end) + '</td>' +
      '<td class="' + cls + '">' + esc(r.subnet) + '</td>' +
      '<td></td><td></td><td></td>' +
      '<td class="td-comment">' + esc(r.comment) + '</td>' +
      '<td class="td-range">' + esc(r.range) + '</td>';
  } else {
    const siteTag = r.site ? '<span class="tag-site site-' + r.site + '">' + r.site + '</span>' : '';
    const vlanTag = r.vlan ? '<span class="tag-vlan">VLAN&nbsp;' + r.vlan + '</span>' : '';
    tr.innerHTML =
      '<td class="td-network">' + esc(r.net) + ' &mdash; ' + esc(r.end) + '</td>' +
      '<td class="td-subnet">' + esc(r.subnet) + '</td>' +
      '<td class="td-gateway">' + esc(r.gw) + '</td>' +
      '<td class="td-desc">' + siteTag + vlanTag + esc(r.desc) + '</td>' +
      '<td class="td-usable">' + r.usable + '</td>' +
      '<td class="td-comment">' + esc(r.comment) + '</td>' +
      '<td class="td-range">' + esc(r.range) + '</td>';
  }

  tbody.appendChild(tr);
});

updateStats();

// ---- Regex helpers ----
function safeRegex(val) {
  if (!val) return null;
  try   { return new RegExp(val, 'i'); }
  catch { return false; }
}

function setValidity(el, re) {
  el.classList.remove('regex-ok','regex-error');
  if (!el.value) return;
  el.classList.add(re === false ? 'regex-error' : 'regex-ok');
}

// ---- Filter ----
function applyFilters() {
  const range   = document.getElementById('filterRange').value;
  const site    = document.getElementById('filterSite').value.toLowerCase();
  const vlan    = document.getElementById('filterVlan').value;

  const commentEl = document.getElementById('filterComment');
  const searchEl  = document.getElementById('searchText');
  const commentRe = safeRegex(commentEl.value);
  const searchRe  = safeRegex(searchEl.value);
  setValidity(commentEl, commentRe);
  setValidity(searchEl,  searchRe);

  let vis = 0, opens = 0;

  document.querySelectorAll('#tbody tr').forEach(tr => {
    const isSpecial = tr.dataset.type === 'open' || tr.dataset.type === 'error';
    let show;

    if (isSpecial) {
      // Gaps: show when range matches and no text filters are active
      const rangeOk   = !range || tr.dataset.range === range;
      const noTextFlt = (!commentEl.value || commentRe === false) &&
                        (!searchEl.value  || searchRe  === false);
      show = rangeOk && !site && !vlan && noTextFlt;
    } else {
      const rangeOk   = !range        || tr.dataset.range === range;
      const siteOk    = !site         || tr.dataset.site  === site;
      const vlanOk    = !vlan         || tr.dataset.vlan  === vlan;
      const commentOk = !commentEl.value || (commentRe && commentRe.test(tr.dataset.comment));
      const searchOk  = !searchEl.value  || (searchRe  && searchRe.test(tr.dataset.all));
      show = rangeOk && siteOk && vlanOk && commentOk && searchOk;
    }

    tr.classList.toggle('hidden', !show);
    if (show) { vis++; if (tr.dataset.type === 'open') opens++; }
  });

  document.getElementById('visCount').textContent  = vis - opens;
  document.getElementById('openCount').textContent = opens;
}

function updateStats() {
  const total = document.querySelectorAll('#tbody tr.row-normal').length;
  const opens = document.querySelectorAll('#tbody tr.row-open').length;
  document.getElementById('totalCount').textContent = total;
  document.getElementById('visCount').textContent   = total;
  document.getElementById('openCount').textContent  = opens;
}

function resetFilters() {
  ['filterRange','filterSite','filterVlan'].forEach(id => document.getElementById(id).value = '');
  ['filterComment','searchText'].forEach(id => {
    const el = document.getElementById(id);
    el.value = '';
    el.classList.remove('regex-ok','regex-error');
  });
  document.querySelectorAll('#tbody tr').forEach(tr => tr.classList.remove('hidden'));
  updateStats();
}

['filterRange','filterSite','filterVlan'].forEach(id =>
  document.getElementById(id).addEventListener('change', applyFilters));
['filterComment','searchText'].forEach(id =>
  document.getElementById(id).addEventListener('input', applyFilters));

// ---- Sort ----
let sortCol = -1, sortAsc = true;

function sortTable(col) {
  const rows = [...document.querySelectorAll('#tbody tr')];
  sortAsc  = (sortCol === col) ? !sortAsc : true;
  sortCol  = col;

  rows.sort((a, b) => {
    const av = a.cells[col] ? a.cells[col].textContent.trim() : '';
    const bv = b.cells[col] ? b.cells[col].textContent.trim() : '';
    const ipA = av.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)/);
    const ipB = bv.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)/);
    if (ipA && ipB) {
      for (let i = 1; i <= 4; i++) {
        const d = parseInt(ipA[i]) - parseInt(ipB[i]);
        if (d) return sortAsc ? d : -d;
      }
      return 0;
    }
    const na = parseFloat(av), nb = parseFloat(bv);
    if (!isNaN(na) && !isNaN(nb)) return sortAsc ? na - nb : nb - na;
    return sortAsc ? av.localeCompare(bv) : bv.localeCompare(av);
  });

  rows.forEach(r => tbody.appendChild(r));

  document.querySelectorAll('thead th').forEach((th, i) => {
    th.classList.remove('sorted','sorted-asc','sorted-desc');
    if (i === col) th.classList.add('sorted', sortAsc ? 'sorted-asc' : 'sorted-desc');
  });
}
</script>
</body>
</html>
HTML
