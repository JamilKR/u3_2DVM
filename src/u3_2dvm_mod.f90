MODULE u3_2dvm_mod
  !
  USE nrtype
  !
  USE defparam_2DVM
  !
  ! by Currix TM
  !
  IMPLICIT NONE
  !
  ! Hamiltonian Matrix
  REAL(KIND = DP), DIMENSION(:,:), ALLOCATABLE :: Ham_matrix 
  ! W^2 Casimir Matrix
  REAL(KIND = DP), DIMENSION(:,:), ALLOCATABLE :: W2_matrix
  ! Eigenvalue Matrix
  REAL(KIND = DP), DIMENSION(:), ALLOCATABLE :: Eigenval_vector ! Hamiltonian Eigenvalues
  ! Cylindrical Oscillator Basis
  TYPE(u2_bas), DIMENSION(:), ALLOCATABLE :: U2_Basis !  U(3) > U(2) > SO(2) basis
  ! Model Hamiltonian Parameters
  INTEGER(KIND = I4B), PARAMETER :: n_modham_param = 2
  REAL(KIND = DP), DIMENSION(1:n_modham_param) :: ModHam_parameter 
  !
  INTEGER(KIND = I4B) :: Ierr, Iprint
  !
  LOGICAL :: Eigenvec_Log     ! If .T. compute eigenvalues and eigenvectors
  LOGICAL :: Excitation_Log   ! If .T. compute excitation energy with respect to L = 0 g.s.
  !
  !
  REAL(KIND = DP) :: GS_energy = 0.0_DP ! L = 0 Ground state energy 
  !
  !
  REAL(KIND = DP), PARAMETER :: Zero_Parameter = 1.0E-20_DP ! Zero limit to discard a parameter evaluation
  !
  REAL(KIND = SP) :: time_check, time_check_ref ! Auxiliary parameters for benchmarking
  !
CONTAINS
  !
  FUNCTION DIM_L_BLOCK(N_val, L_val)
    !
    IMPLICIT NONE
    !
    !
    INTEGER(KIND = I4B), INTENT(IN) :: N_val ! U(4) [N]
    !
    INTEGER(KIND = I4B), INTENT(IN) :: L_val ! Angular momentum
    !
    !
    INTEGER(KIND = I4B) :: DIM_L_BLOCK 
    !
    !
    DIM_L_BLOCK = (N_val - MOD(N_val - l_val ,2_I4B) - l_val)/2_I4B + 1_I4B
    !
    !
  END FUNCTION DIM_L_BLOCK
  !
  SUBROUTINE U2_BASIS_VIBRON(N_val, L_val, U2_Basis) 
    !
    ! Subroutine to build the U(3) > U(2) > SO(2) basis in the 2DVM
    !
    !  by Currix TM.
    !
    IMPLICIT NONE
    !
    INTEGER(KIND = I4B), INTENT(IN) :: N_val ! U(3) [N]
    !
    INTEGER(KIND = I4B), INTENT(IN) :: L_val ! Vibrational Angular momentum
    !
    TYPE(u2_bas), DIMENSION(:), INTENT(OUT) :: U2_Basis
    !
    ! Local Variables
    INTEGER(KIND = I4B) :: index, np
    !
    index = 1_I4B
    !
    np = L_val
    !
    DO WHILE (np <= N_val) 
       !
       U2_Basis(index)%np_U2_val = np
       !
       index = index + 1_I4B
       np = np + 2_I4B
       !
    ENDDO
    !
    U2_Basis(1:Index-1)%N_U3_val = N_val
    U2_Basis(1:Index-1)%L_val = L_val
    !
    !
  END SUBROUTINE U2_BASIS_VIBRON
  !
  SUBROUTINE SO3_Cas_Build(N_val, L_val, dim_block, U2_basis, W2_matrix)
    !
    ! Subroutine to build the SO(3) W^2 Casimir operator in the 2DVM
    !
    !  by Currix TM.
    !
    IMPLICIT NONE
    !
    INTEGER(KIND = I4B), INTENT(IN) :: N_val ! U(3) [N]
    !
    INTEGER(KIND = I4B), INTENT(IN) :: L_val ! Vibrational Angular momentum
    !
    INTEGER(KIND = I4B), INTENT(IN) :: dim_block ! Block dimension for N_val and L_val
    !
    TYPE(u2_bas), DIMENSION(:), INTENT(IN) :: U2_Basis ! Cylindrical oscillator basis
    !
    REAL(KIND = DP), DIMENSION(:,:), INTENT(OUT) :: W2_matrix
    !
    ! Local variables
    INTEGER(KIND = I4B) :: index
    REAL(KIND = DP) :: Nvalue, Lvalue
    REAL(KIND = DP) :: npvalue, tempval
    !
    ! Initialize
    W2_matrix = 0.0_DP
    Nvalue = REAL(N_val,DP)
    Lvalue =  REAL(L_val,DP)
    !
    ! NON-DIAGONAL PART
    DO index = 2, dim_block  
       npvalue = REAL(U2_Basis(index)%np_U2_val, DP)
       tempval = SQRT((Nvalue - npvalue + 2.0_DP)*(Nvalue - npvalue + 1.0_DP)*(npvalue + Lvalue)*(npvalue - Lvalue))
       W2_matrix(index-1,index) = -tempval
       W2_matrix(index,index-1) = -tempval
    ENDDO
    !
    ! DIAGONAL PART
    DO index = 1, dim_block                     
       npvalue = REAL(U2_Basis(index)%np_U2_val, DP)
       W2_matrix(index,index) = (Nvalue - npvalue)*(npvalue + 2.0_DP) + (Nvalue - npvalue + 1.0_DP)*npvalue + Lvalue*Lvalue
    ENDDO
    !
    RETURN
    !
  END SUBROUTINE SO3_Cas_Build
    !
  SUBROUTINE Build_Mod_Ham(N_val, L_val, dim_block, U2_Basis, W2_casimir, Ham_U3_mat) 
    !
    !
    ! Subroutine to build the U(3) 2DVM Model Hamiltonian
    ! Cylindrical Oscillator Basis U(2)
    !
    !  by Currix TM.
    !
    IMPLICIT NONE
    !
    INTEGER(KIND = I4B), INTENT(IN) :: N_val ! U(3) [N]
    !
    INTEGER(KIND = I4B), INTENT(IN) :: L_val ! Angular momentum
    !
    INTEGER(KIND = I4B), INTENT(IN) :: dim_block ! Angular momentum L_val block dimension
    !
    TYPE(u2_bas), DIMENSION(:), INTENT(IN) :: U2_Basis   ! U2 basis   { | [N] np L > }
    !
    REAL(KIND = DP), DIMENSION(:,:), INTENT(OUT) :: W2_casimir ! SO(3) W^2 casimir matrix
    !
    REAL(KIND = DP), DIMENSION(:,:), INTENT(OUT) :: Ham_U3_mat ! Hamiltonian matrix
    !
    INTEGER(KIND = I4B) :: oper, U2_state
    REAL(KIND = DP) :: npvalue, Nvalue
    !
    !
    Nvalue = REAL(N_val, DP)
    !
    ! Build Hamiltonian
    operator : DO oper = 1, n_modham_param
       !
       IF (Iprint > 1) WRITE(*,*) "Operator number ", oper
       !
       IF (ABS(ModHam_parameter(oper)) < Zero_Parameter) CYCLE ! Skip not needed operators
       !
       SELECT CASE (oper)
          !
       CASE (1) ! n ---> DIAGONAL
          !
          DO U2_state = 1, dim_block
             !
             npvalue = REAL(U2_Basis(U2_state)%np_U2_val, DP)
             !
             Ham_U3_mat(U2_state, U2_state) = Ham_U3_mat(U2_state, U2_state) + &
                  ModHam_parameter(1)*npvalue
             !
          ENDDO
          !
          !
       CASE (2) ! Pairing Operator
          !
          CALL SO3_Cas_Build(N_val, L_val, dim_block, U2_basis, W2_matrix)
          !
          Ham_U3_mat = Ham_U3_mat -  ModHam_parameter(2)*W2_matrix
          !
          ! Diagonal Pairing contribution
          DO U2_state = 1, dim_block
             !
             Ham_U3_mat(U2_state, U2_state) = Ham_U3_mat(U2_state, U2_state) + &
                  ModHam_parameter(2)*Nvalue*(Nvalue + 1_I4B)
             !
          ENDDO
          !
       CASE DEFAULT
          !
          STOP 'You should not be here. Invalid nonzero parameter number. Sayonara baby.'
          !
       END SELECT
       !
    ENDDO operator
    !
    !
  END SUBROUTINE BUILD_MOD_HAM
  !
  FUNCTION POCCHAMMER_S(a, b)
    !
    ! Pocchammer symbol as defined in Frank and Isacker 5.176 p.162
    ! (rising factorial)
    !
    ! by Currix TM
    !
    USE nrtype
    !
    IMPLICIT NONE
    !
    INTEGER(KIND=I4B), INTENT(IN) :: a, b
    INTEGER(KIND=I4B) :: POCCHAMMER_S
    !
    INTEGER(KIND=I4B) :: index  
    !
    POCCHAMMER_S = a
    !
    DO index = 1, b - 1
       POCCHAMMER_S = POCCHAMMER_S * (a + index)
    ENDDO
    !
    !
    !
  END FUNCTION POCCHAMMER_S
  !
  FUNCTION Inv_Part_Ratio(N_val, L_val, dim_block, U2_Basis, eigenvector)
    !
    ! Subroutine to compute the IPR for a 2DVM eigenstate
    !
    !  by Currix TM.
    !
    IMPLICIT NONE
    !
    INTEGER(KIND = I4B), INTENT(IN) :: N_val ! U(3) [N]
    !
    INTEGER(KIND = I4B), INTENT(IN) :: L_val ! Angular momentum
    !
    INTEGER(KIND = I4B), INTENT(IN) :: dim_block ! Angular momentum L_val block dimension
    !
    TYPE(u2_bas), DIMENSION(:), INTENT(IN) :: U2_Basis   ! U2 basis   { | [N] np L > }
    !
    REAL(KIND = DP), DIMENSION(:), INTENT(IN) :: eigenvector ! Eigenvector components (U(2) basis)
    !
    REAL(KIND = DP) :: Inv_Part_Ratio
    !
    ! Local Variables
    INTEGER(KIND = I4B) :: n1, n2, n3, n4, i1, i2, i3, i4, iprod
    REAL(KIND = DP) :: prodval
    !
    Inv_Part_Ratio = 0.0_DP
    !
    DO i1 = 1, dim_block
       n1 = U2_Basis(i1)%np_U2_val
       !
       DO i2 = 1, dim_block
          n2 = U2_Basis(i2)%np_U2_val
          !
          DO i3 = 1, dim_block
             n3 = U2_Basis(i3)%np_U2_val
             !
             DO i4 = 1, dim_block
                n4 = U2_Basis(i4)%np_U2_val
                !
                IF (n1 + n2 /= n3 + n4) CYCLE
                !
                prodval = SQRT( REAL(POCCHAMMER_S(N_val - n1 + 1, n1),DP)/&
                     (GAMMA(REAL((n1 + l_val)/2 + 1,DP))*GAMMA(REAL((n1 - l_val)/2 + 1,DP)) ) ) * &
                     SQRT( REAL(POCCHAMMER_S(N_val - n2 + 1, n2),DP)/&
                     (GAMMA(REAL((n2 + l_val)/2 + 1,DP))*GAMMA(REAL((n2 - l_val)/2 + 1,DP)) ) ) * &
                     SQRT( REAL(POCCHAMMER_S(N_val - n3 + 1, n3),DP)/&
                     (GAMMA(REAL((n3 + l_val)/2 + 1,DP))*GAMMA(REAL((n3 - l_val)/2 + 1,DP)) ) ) * &
                     SQRT( REAL(POCCHAMMER_S(N_val - n4 + 1, n4),DP)/&
                     (GAMMA(REAL((n4 + l_val)/2 + 1,DP))*GAMMA(REAL((n4 - l_val)/2 + 1,DP)) ) )
                !
                prodval = prodval * eigenvector(i1)* eigenvector(i2)* eigenvector(i3)* eigenvector(i4)
                !
                prodval = prodval * GAMMA(REAL((n1+n2)/2+1, DP))**2 * GAMMA(REAL(2*N_val - n1 - n2 + 1,DP))
                !
                Inv_Part_Ratio = Inv_Part_Ratio + prodval
                !
             ENDDO
             !
          ENDDO
          !
       ENDDO
       !
    ENDDO
    !
    Inv_Part_Ratio = Inv_Part_Ratio * REAL(N_val + 2_I4B, DP)/2.0_DP
    !
  END FUNCTION Inv_Part_Ratio
  !
  !
END MODULE u3_2dvm_mod
