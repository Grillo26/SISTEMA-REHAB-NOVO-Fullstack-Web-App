package com.cemt.backend_novo.modules.user.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Data
@Entity
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "usuario")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    Long id;

    @Column(name = "tenant_id", nullable = false)
    private String tenantId = "default";

    private String username;

    @Column(name = "password_hash", length = 255, nullable = false)
    private String passwordHash;

    @Column(length = 150)
    private String email;

    @Column(length = 100)
    private String nombres;

    @Column(length = 100)
    private String apellidos;

    @Column(name = "rol_id",nullable = false)
    private Long rolId;

    private Boolean activo = true;

    private LocalDateTime created_at;

}
