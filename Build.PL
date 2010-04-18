use Module::Build;

my $mb = Module::Build->new(
    module_name     => 'Test::Mock::LWP::Dispatch',
    license         => 'perl',
    dist_author     => 'Yury Zavarin <yury.zavarin@gmail.com>',
    requires        => {
        'Module::Build'    => 0.2805,
        'Carp'             => 0,
        'Exporter'         => 0,
        'Data::Dumper'     => 0,
        'LWP::UserAgent'   => 0,
        'Test::MockObject' => 0,
    },
    build_requires => {
        'Test::More'            => 0,
        'Test::Exception'       => 0,
    }
);

$mb->create_build_script;
