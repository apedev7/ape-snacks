#!/usr/bin/perl
#------------------------------------------------------------------
#
#  cs-gen.pl
#
#  Generate Cscope DB of curdir, with DB placed in curdir/Cscope.gen
#
#------------------------------------------------------------------
#
use strict;
use Cwd 'realpath';

sub usage {
  print STDERR "\n";
  print STDERR "Usage: cs-gen.pl [-s]"
               . " [-P pattern1[:pattern2]...]"
               . " [-p pattern1[:pattern2]...]"
               . " [-r pattern1[:pattern2]...]"
               . " [-x external-prog[,prog-opt[,prog-opt]]]"
               . " [path...]\n";
  print STDERR "  -P to give a complete filter-in patterns\n" .
               "  -p to add to default filter-in patterns\n" .
               "  -r to add to default filter-out patterns\n";
  print STDERR "  -s skip file rescan\n";
  print STDERR "  path default is curdir\n";
  print STDERR "Hints:\n";
  print STDERR " -- be sure to reject ChangeLog* for GNU trees\n";
  exit 1;
}

my $rescan = 1;
my $xprog = "";

my @files = ("*.[c,h,s,S,x]",
             "*.cc",
             "*.go",
             "*.java",
             "*Make*",
             "*.mk",
             "*.pl",
             "*.sh"
            );

my @rejects = (".*",
               "*~",
               "CVS"
              );

my $arg0 = 0;
for (my $a = 0; $a <= $#ARGV; $a += 1) {
  my $argv = $ARGV[$a];

  if ($argv eq "-help") {
    usage();
  }

  if ($argv eq "-s") {
    $rescan = 0;
    next;
  }

  if ($argv eq "-P") {
    $a += 1;
    @files = split(/:/, $ARGV[$a]);
    next;
  }

  if ($argv eq "-p") {
    $a += 1;
    push @files, split(/:/, $ARGV[$a]);
    next;
  }

  if ($argv eq "-r") {
    $a += 1;
    push @rejects, split(/:/, $ARGV[$a]);
    next;
  }

  if ($argv eq "-x") {
    $a += 1;

    my $xa = $ARGV[$a];
    $xa =~ s/,/ /g;

    $xprog .= " $xa";  # concat all -x into a single cmd
    next;
  }

  $arg0 = $a;
  last;
}

# collect the paths to be scanned
my $srcdir = "";
foreach my $srctop (@ARGV[$arg0..$#ARGV]) {
  if (! -e $srctop) {
    die "$srctop: directory does not exist\n";
  }
  $srcdir = "$srcdir " . get_abspath($srctop);
}

if ($srcdir eq "") {
  $srcdir = get_abspath(".");
}

# expand $srcdir to include 'gen' symlinked subdirs
my @gentop;

print STDERR "Scanning $srcdir for installed linux/opt...\n";
push @gentop, (`ls -d $srcdir/pkt/*/linux/opt`);

print STDERR "Scanning $srcdir for symlinked gen...\n";
push @gentop, (`find $srcdir -type l -a -name gen -printf "%l\n"`);

foreach my $srctop (@gentop) {
  chomp $srctop;
  if (-d $srctop) {
    $srcdir = "$srcdir " . get_abspath($srctop);
  }
}

# basic defines
my $find_pat = "-path '*/CVS' -prune"
               . " -o -path '*/Cscope.gen' -prune"
               . " -o -path '*/.*' -prune"
               . " -o -type f"
               . " -a " . mk_find(@files)
               . " -a \\! " . mk_find(@rejects);

my $cs_dir = "Cscope.gen";
my $cs_list = "$cs_dir/cscope-files";
my $cs_temp = get_abspath($cs_dir);

# intentionally use what is in user's path
my $FIND = "find -H $srcdir $find_pat -print";
my $SORT = "sort -u -o $cs_list $cs_list";
my $CSCOPE = "cd $cs_dir; cscope -b -i ../$cs_list -k -q -u";

$FIND .= "| $xprog" if (length($xprog) > 0);

# prepare the file list
if (! -d $cs_dir) {
  $rescan = 1;
} elsif (! -r $cs_list) {
  $rescan = 1;
}

if ($rescan != 0) {
  mkdir_if($cs_dir);
  open(FIND_LIST, ">$cs_list")
    || die "Error $! when opening $cs_list for write\n";
  open(FIND_STDOUT, $FIND . " |")
    || die "Error $! when spawns:\n\t$FIND\n";
  print STDERR "Running $FIND\n";
  my $next_time = time();
  my $count = 0;
  my @bad_name;
  while (<FIND_STDOUT>) {
    ++$count;
    if (time() >= $next_time) {
      ++$next_time;
      print STDERR "\rScanned $count files...";
    }
    chomp;
    if (/\s/) {
      push @bad_name, $_;
      next;
    }
    print FIND_LIST "$_\n" || die "Error $1 when writing $cs_list\n";
  }
  close(FIND_LIST);
  close(FIND_STDOUT);
  print STDERR "\rTotal $count files       \n";
  $count = scalar(@bad_name);
  if ($count > 0) {
    print STDERR "... with $count files skipped due to invalid name\n";

    my $bad = "$cs_list.bad";
    open(BAD_LIST, ">$bad")
    || die "Error $! when opening $bad for write\n";
    print BAD_LIST join("\n", @bad_name) . "\n";
    close(BAD_LIST);
  }

  print STDERR "Running $SORT\n";
  system($SORT);
}

print STDERR "Running $CSCOPE\n";
$ENV{TMPDIR}="$cs_temp";
exec($CSCOPE);

# error if exec returns
die "Error '$!' when executing:\n\t$CSCOPE\n";

sub get_abspath {
  my $dir = $_[0];

  if (! -d $dir) {
    if ($dir =~ m{(^.*/)(.*$)}) {
      $dir = `cd $1; echo \$PWD`;
      chomp $dir;
      $dir = $dir . "/$2";
    } else {
      $dir = $ENV{PWD} . "/$dir";
    }
  } elsif ($dir eq ".") {
    $dir = $ENV{PWD};
  } else {
    $dir = `cd $dir; echo \$PWD`;
    chomp $dir;
  }

  return realpath($dir);
}

sub mk_find {
  my $list = "";
  my $or_op = "\\(";
  my $i;
  for ($i = 0; $i < @_; ++$i) {
    $list = $list . "$or_op -name '$_[$i]'";
    $or_op = " -o";
  }
  $list = $list . " \\)";

  return $list;
}

sub mkdir_if {
  my $name = $_[0];
  if (-e $name) {
    if (! -d $name) {
      printf STDERR "$name: a non-subdir of same name already exists!\n";
      exit 1;
    }
    foreach my $c ($cs_list, "cscope.in.out", "cscope.out", "cscope.po.out") {
      my $cn = "$name/$c";
      if (-e $cn) {
        print STDERR "unlink $cn\n";
        unlink($cn) || die "$cn: unable to unlink; $!\n";
      }
    }
  } else {
    mkdir $name || die "$name: cannot create the subdir; $!\n";
  }
}
