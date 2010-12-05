package Catmandu;

our $VERSION = 0.01;

use 5.010;
use MooseX::Singleton;
use Try::Tiny;
use Template;
use File::ShareDir;
use Path::Class ();
use Hash::Merge ();
use YAML ();
use JSON ();

has catmandu_share => (is => 'ro', isa => 'Str', init_arg => undef, builder => '_build_catmandu_share');
has catmandu_lib   => (is => 'ro', isa => 'Str', init_arg => undef, builder => '_build_catmandu_lib');
has home => (is => 'ro', isa => 'Str', required => 1);
has env  => (is => 'ro', isa => 'Str', required => 1);
has stack     => (is => 'ro', isa => 'ArrayRef', init_arg => undef, lazy => 1, builder => '_build_stack');
has conf      => (is => 'ro', isa => 'HashRef',  init_arg => undef, lazy => 1, builder => '_build_conf');
has _template => (is => 'ro', isa => 'Template', init_arg => undef, lazy => 1, builder => '_build_template');
has _stash    => (is => 'ro', isa => 'HashRef',  init_arg => undef, lazy => 1, default => sub { +{} });

sub _build_catmandu_share {
    try {
        File::ShareDir::module_dir(__PACKAGE__);
    } catch {
        Path::Class::file(__FILE__)->dir->parent->subdir('share')->resolve->stringify;
    };
}

sub _build_catmandu_lib {
    Path::Class::file(__FILE__)->dir->absolute->resolve->stringify;
}

sub _build_stack {
    my $self = shift;
    my $file = Path::Class::file($self->home, "catmandu.yml")->stringify;
    -f $file or return ['catmandu-base'];
    my $dirs = YAML::LoadFile($file);
    if (! grep /^catmandu-base$/, @$dirs) {
        push @$dirs, 'catmandu-base';
    }
    $dirs;
}

sub _build_conf {
    my $self = shift;
    my $merger = Hash::Merge->new('RIGHT_PRECEDENT');
    my $conf = {};

    foreach my $conf_path ( reverse @{$self->paths('conf')} ) {
        Path::Class::dir($conf_path)->recurse(depthfirst => 1, callback => sub {
            my $file = shift;
            my $path = $file->stringify;
            my $hash;
            -f $path or return;
            given ($path) {
                when (/\.json$/)  { $hash = JSON::decode_json($file->slurp) }
                when (/\.ya?ml$/) { $hash = YAML::LoadFile($path) }
                when (/\.pl$/)    { $hash = do $path }
            }
            if (ref $hash eq 'HASH') {
                $conf = $merger->merge($conf, $hash);
            }
        });
    }

    # load env specific conf
    if (my $hash = delete $conf->{$self->env}) {
        $conf = $merger->merge($conf, $hash);
    }

    $conf;
}

sub _build_template {
    my $self = shift;
    my $args = $self->conf->{template}{args} || {};
    Template->new({
        INCLUDE_PATH => $self->paths('template'),
        %$args,
    });
}

sub print_template {
    my $self = shift;
    my $tmpl = $self->_template;
    my $file = shift;
    $file = "$file.tt" if $file !~ /\.tt$/;
    $tmpl->process($file, @_)
        or confess $tmpl->error;
}

sub stash {
    my $self = shift;
    my $hash = $self->_stash;
    return $hash          if @_ == 0;
    return $hash->{$_[0]} if @_ == 1;
    my %pairs = @_;
    while (my ($key, $val) = each %pairs) {
        $hash->{$key} = $val;
    }
    $hash;
}

sub paths {
    my ($self, $dir) = @_;
    my $stack = $self->stack;
    my $paths = [$self->home,
                 map { Path::Class::dir(/^catmandu-/ ? $self->catmandu_share : $self->home, $_)->stringify } @$stack];
    if ($dir) {
        [ grep { -d $_ } map { Path::Class::dir($_, $dir)->stringify } @$paths ];
    } else {
        $paths;
    }
}

sub path {
    my ($self, $dir) = @_;
    $self->paths($dir)->[0];
}

sub files {
    my ($self, $dir, $file) = @_;
    my $paths = $self->paths($dir);
    [ grep { -f $_ } map { Path::Class::file($_, $file)->stringify } @$paths ];
}

sub file {
    my ($self, $dir, $file) = @_;
    $self->files($dir, $file)->[0];
}

sub lib {
   @{$_[0]->paths('lib')};
}

__PACKAGE__->meta->make_immutable;
no MooseX::Singleton;
no List::Util;
__PACKAGE__;

