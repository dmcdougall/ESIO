!!-----------------------------------------------------------------------bl-
!!--------------------------------------------------------------------------
!!
!! ESIO 0.2.0: ExaScale IO library for turbulence simulation restart files
!! http://red.ices.utexas.edu/projects/esio/
!!
!! Copyright (C) 2010-2014 The PECOS Development Team
!!
!! This file is part of ESIO.
!!
!! ESIO is free software: you can redistribute it and/or modify
!! it under the terms of the GNU Lesser General Public License as published
!! by the Free Software Foundation, either version 3.0 of the License, or
!! (at your option) any later version.
!!
!! ESIO is distributed in the hope that it will be useful,
!! but WITHOUT ANY WARRANTY; without even the implied warranty of
!! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!! GNU Lesser General Public License for more details.
!!
!! You should have received a copy of the GNU Lesser General Public License
!! along with ESIO.  If not, see <http://www.gnu.org/licenses/>.
!!
!!-----------------------------------------------------------------------el-
!! $Id$

!> Program designed to 'chunk' a field into multiple pieces so we can
!! load it up into an HDF-like storage.  Ideally, field should be similar
!! to what is currently used in PSDNS.
!!
!! This routine will therefore be an early test for the ESIO library.
program p3dfft_like

  use esio

! The header contains problem size, initial conditions, precision, etc.
! The header declares physical space extents but xis{t,z}/zjs{t,z} and
! local storage u are allocated using the wave space extents.
  use p3dfft_like_header, only: ny, nx, nz, nc,            & ! Physical space
                                xist, xisz, zjst, zjsz, u, & ! Wave space
                                initialize_problem, initialize_field
  implicit none

  include 'mpif.h'      !! More portable than 'use mpi' on old implementations

  integer(4)            :: myid, numprocs, ierr, i
  integer(4), parameter :: niter = 1
  type(esio_handle)     :: handle

  character(len=20) :: filename  = "outpen.1.h5"
  character(len=20) :: fieldname = "u.field"

  real(8) :: stime, etime ! timers

  call mpi_init(ierr)
  call mpi_comm_rank(mpi_comm_world, myid, ierr)
  call mpi_comm_size(mpi_comm_world, numprocs, ierr)

  if (myid.eq.0) write(*,*) "initializing esio"
  call esio_handle_initialize(handle, mpi_comm_world)
  call esio_file_create(handle, filename, .TRUE.)

  if (myid.eq.0) write(*,*) "initializing problem"
  call initialize_problem(myid,numprocs)

  if (myid.eq.0) write(*,*) "initializing field:", ny, nz, nx, nc
  call initialize_field(myid)

! Print domain decomposition details on each MPI rank
! do i = 0, numprocs - 1
!   call mpi_barrier(mpi_comm_world, ierr)
!   if (myid.eq.i) then
!     write(*,*) myid, "local field has shape:  ", shape(u)
!     write(*,*) myid, "local xis{tz}, zjs{tz}: ", xist, xisz, zjst, zjsz
!     flush (6)
!   end if
!   call mpi_barrier(mpi_comm_world, ierr)
! end do

  call esio_field_establish(handle, ny, 1,    ny,      &
                                    nx, xist, xisz,    &
                                    nz, zjst, zjsz)
  stime = mpi_wtime()
  do i = 1, niter
    call esio_field_writev(handle, fieldname, u, nc) ! Precision-agnostic!!!
  end do
  etime = mpi_wtime()

  if (myid.eq.0) then
    write(*,*) "program is finalizing, time was: ", etime-stime
    write(*,*) "In ", niter, " iterations"
    write(*,*) "wrote / read: ", &
               niter*(nc*8*ny*nz*real(nx/2.))/(10e6), " MB"
    write(*,*) "speed: ", &
               (niter*(nc*8*ny*nz*nx/2.)/(10e6))/(etime-stime), " MB/s"
  end if

  call esio_file_close(handle)
  call esio_handle_finalize(handle)
  call mpi_finalize(ierr)

end program p3dfft_like
