from spack import *

class Triqs(CMakePackage):
    """TRIQS: a Toolbox for Research on Interacting Quantum Systems"""

    homepage = "https://triqs.github.io"
    url      = "https://github.com/TRIQS/triqs/archive/refs/tags/3.0.0.tar.gz"

    version('3.0.1', sha256='d555a4606c7ea2dde28aa8da056c6cc1ebbdd4e11cdb50b312b8c8f821a3edd2')
    version('3.0.x', git='https://github.com/TRIQS/triqs.git', branch='3.0.x')

    variant('libclang', default=True, description='Build against libclang to enable c++2py support. ')

    # TRIQS Dependencies
    depends_on('cmake', type='build')
    depends_on('mpi', type=('build', 'link'))
    depends_on('blas', type=('build', 'link'))
    depends_on('lapack', type=('build', 'link'))
    depends_on('fftw@3:', type=('build', 'link'))
    depends_on('boost', type=('build', 'link'))
    depends_on('gmp', type=('build', 'link'))
    depends_on('hdf5', type=('build', 'link'))
    depends_on('llvm', type=('build', 'link'), when='+libclang')
    depends_on('python@3.7:', type=('build', 'link', 'run'))
    depends_on('py-scipy', type=('run'))
    depends_on('py-numpy', type=('run'))
    depends_on('py-h5py', type=('run'))
    depends_on('py-mpi4py', type=('run'))
    depends_on('py-matplotlib', type=('run'))
    depends_on('py-mako', type=('run'))
    depends_on('py-sphinx', type=('run'))

    extends('python')
