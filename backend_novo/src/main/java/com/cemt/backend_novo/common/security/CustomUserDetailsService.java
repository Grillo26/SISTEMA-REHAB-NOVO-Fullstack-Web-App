package com.cemt.backend_novo.common.security;

import com.cemt.backend_novo.modules.role.model.Rol;
import com.cemt.backend_novo.modules.role.repository.RolRepository;
import com.cemt.backend_novo.modules.user.model.User;
import com.cemt.backend_novo.modules.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final RolRepository rolRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // Cargar tu entidad User
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado: " + username));

        // Obtener el rol
        Long rolId = user.getRolId();
        Rol rol = rolRepository.findById(rolId)
                .orElseThrow(() -> new RuntimeException("Rol no encontrado para usuario: " + username));
        String roleName = rol.getNombre();

        // Construir authorities
        Set<GrantedAuthority> authorities = Collections.singleton(
                new SimpleGrantedAuthority("ROLE_" + roleName)
        );

        // Retornar UserDetails de Spring Security con los parámetros correctos
        return new org.springframework.security.core.userdetails.User(
                user.getUsername(),          // username
                user.getPasswordHash(),      // password (el hash almacenado)
                user.getActivo(),            // enabled (true/false)
                true,                        // accountNonExpired
                true,                        // credentialsNonExpired
                true,                        // accountNonLocked
                authorities
        );
    }
}