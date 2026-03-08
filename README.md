# RecuerdaMed

RecuerdaMed es una aplicación móvil desarrollada con Flutter cuyo objetivo es ayudar a los usuarios a gestionar y recordar la toma de su medicación diaria de forma sencilla y visual.

Este proyecto ha sido realizado como **trabajo académico**, centrado principalmente en el diseño de pantallas y la navegación entre ellas, sin implementar lógica de negocio ni persistencia real de datos.

---

## 🎯 Objetivo del proyecto

El objetivo principal de RecuerdaMed es ofrecer una interfaz clara e intuitiva que permita:

- Visualizar las tomas de medicación del día.
- Gestionar una lista de medicamentos.
- Consultar un historial de tomas.
- Acceder a un perfil de usuario con información básica.

La aplicación está pensada para ser fácil de usar y comprensible para cualquier tipo de usuario.

---

## 📱 Pantallas incluidas

La aplicación cuenta con las siguientes pantallas:

- **Login**: acceso inicial a la aplicación.
- **Hoy**: muestra las tomas de medicación programadas para el día actual.
- **Medicamentos**: listado de medicamentos registrados.
- **Añadir medicamento**: formulario para añadir un nuevo medicamento.
- **Historial**: registro visual de tomas realizadas y omitidas.
- **Perfil**: información del usuario y opciones de configuración.

Todas las pantallas están maquetadas y conectadas mediante navegación básica.

---

## 🛠️ Tecnologías utilizadas

- **Flutter**
- **Dart**
- **Material Design**
- **Android Studio / Visual Studio Code**

No se utiliza base de datos ni API real, ya que el enfoque del proyecto es la parte visual y la navegación.

---

## 🧭 Navegación

La aplicación utiliza:

- Navegación con `Navigator`
- Barra de navegación inferior para las pantallas principales:
  - Hoy
  - Medicamentos
  - Historial
  - Perfil

---

## 📂 Estructura del proyecto

```text
lib/
├── main.dart
├── app.dart
├── screens/
│   ├── login_screen.dart
│   ├── today_screen.dart
│   ├── medication_screen.dart
│   ├── add_medication_screen.dart
│   ├── history_screen.dart
│   └── profile_screen.dart
├── services/
│   ├── notification_service.dart
