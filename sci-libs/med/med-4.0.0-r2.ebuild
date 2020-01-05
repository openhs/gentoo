# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# EAPI=7 uses ninja generator by default but it's incompatible with USE=fortran
# https://github.com/Kitware/ninja/tree/features-for-fortran#readme
CMAKE_MAKEFILE_GENERATOR=emake

FORTRAN_NEEDED=fortran

# NOTE:The build for multiple python versions should be possible but
# complicated for the build system
PYTHON_COMPAT=( python3_{6,7} )

inherit cmake fortran-2 python-single-r1

DESCRIPTION="A library to store and exchange meshed data or computation results"
HOMEPAGE="https://www.salome-platform.org/user-section/about/med"
SRC_URI="https://files.salome-platform.org/Salome/other/${P}.tar.gz"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc fortran mpi python test"

REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

RESTRICT="!test? ( test ) python? ( test )"

# dev-lang/tk is needed for wish-based xmdump utility
RDEPEND="
	!sci-libs/libmed
	dev-lang/tk:0=
	>=sci-libs/hdf5-1.10.2:=[fortran?,mpi?]
	mpi? ( virtual/mpi[fortran=] )
	python? ( ${PYTHON_DEPS} )
"
DEPEND="${RDEPEND}"
BDEPEND="python? ( >=dev-lang/swig-3.0.8 )"

PATCHES=(
	"${FILESDIR}/${PN}-3.3.1-cmake-fortran.patch"
	"${FILESDIR}/${PN}-3.3.1-disable-python-compile.patch"  # managed by function of python eclass
	"${FILESDIR}/${P}-cmakelist.patch"
	"${FILESDIR}/${P}-installdoc.patch"
)

DOCS=( AUTHORS ChangeLog NEWS README TODO )

pkg_setup() {
	use python && python-single-r1_pkg_setup
	use fortran && fortran-2_pkg_setup
}

src_prepare() {
	if use python; then
		# fixes for correct libdir name
		local pysite=$(python_get_sitedir)
		pysite="${pysite##/usr/}"
		sed \
			-e 's@SET(_install_dir lib/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}/site-packages/med)@SET(_install_dir '${pysite}'/med)@' \
			-i ./python/CMakeLists.txt || die "sed on ./python/CMakeLists.txt failed"
	fi
	for cm in ./src/CMakeLists.txt ./tools/medimport/CMakeLists.txt
	do
		sed -i -e "s@INSTALL(TARGETS \(.*\) DESTINATION lib)@INSTALL(TARGETS \1 DESTINATION $(get_libdir))@" \
			"${cm}" || die "sed on ${cm} failed"
	done

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# as indicated in the CMakeLists.txt, the shipped documentation is generated by a custom doxygen,
		# so let's avoid rebuilding it because it will be different
		-DMEDFILE_BUILD_DOC=OFF
		-DMEDFILE_BUILD_FORTRAN=$(usex fortran)
		-DMEDFILE_BUILD_PYTHON=$(usex python)
		-DMEDFILE_BUILD_SHARED_LIBS=ON
		-DMEDFILE_BUILD_STATIC_LIBS=OFF
		-DMEDFILE_BUILD_TESTS=$(usex test)
		-DMEDFILE_DOC_DIRECTORY="${EPREFIX}"/usr/share/doc/${PF}/html   # custom var created by patches
		-DMEDFILE_INSTALL_DOC=$(usex doc)
		-DMEDFILE_USE_MPI=$(usex mpi)
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# we don't need old 2.3.6 include files
	rm -r "${ED}"/usr/include/2.3.6 || die "failed to delete obsolete include dir"

	# the optimization done in CMakeLists.txt has been disabled so
	# we need to do it manually
	use python && python_optimize

	# Prevent test executables being installed
	if use test; then
		rm -r "${ED}"/usr/bin/testc || die "failed to delete C test executables"
		if use fortran; then
			rm -r "${ED}"/usr/bin/testf || die "failed to delete fortran test executables"
		fi
		if use python; then
			rm -r "${ED}"/usr/bin/testpy || die "failed to delete python test executables"
		fi
	fi
}

src_test() {
	# override parallel mode only for tests
	local myctestargs=( "-j 1" )
	cmake_src_test
}
