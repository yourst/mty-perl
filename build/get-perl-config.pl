use Config;
foreach my $k (qw(VERSION ARCHNAME PERLPATH SITELIB SITEARCH )) 
  { print("PERL_".uc($k)." := ".$Config{lc($k)}."\n"); }
