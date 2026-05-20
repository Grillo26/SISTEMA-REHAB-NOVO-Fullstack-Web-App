package com.cemt.backend_novo.modules.auth.controller;

import com.cemt.backend_novo.common.jwt.JwtUtil;
import com.cemt.backend_novo.modules.auth.dto.LoginRequest;
import com.cemt.backend_novo.modules.auth.dto.LoginResponse;
import com.cemt.backend_novo.modules.user.model.User;
import com.cemt.backend_novo.modules.user.repository.UserRepository;
import com.cemt.backend_novo.modules.role.repository.RolRepository;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final RolRepository rolRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthController(AuthenticationManager authenticationManager, JwtUtil jwtUtil,
                          UserRepository userRepository, RolRepository rolRepository,
                          PasswordEncoder passwordEncoder) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.rolRepository = rolRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
        );
        SecurityContextHolder.getContext().setAuthentication(authentication);

        User user = userRepository.findByUsername(request.getUsername())
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        String token = jwtUtil.generateToken(user.getUsername());
        String rolNombre = rolRepository.findById(user.getRolId()).get().getNombre();

        return new LoginResponse(token, "Bearer", user.getUsername(), rolNombre);
    }

    @PostMapping("/register")
    public String register(@RequestBody LoginRequest request) {
        String encodedPassword = passwordEncoder.encode(request.getPassword());
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPasswordHash(encodedPassword);
        user.setRolId(1L); // ADMIN u otro
        user.setActivo(true);
        userRepository.save(user);
        return "Usuario creado";
    }
}