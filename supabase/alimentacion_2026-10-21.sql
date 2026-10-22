-- Alimentación, parte 1 (2026-10-21): registro de comidas con contador aproximado + agua.
-- alimentos: base compartida (valores por 100 g, aproximados de tablas de composición estándar).
--   Lectura para cualquier autenticada; escritura solo admin.
-- comidas: lo que registra cada clienta (se guardan los valores calculados al momento de registrar).
-- agua: vasos por día.
-- Cada clienta solo ve y cambia lo suyo; el admin lee todo.

create table if not exists public.alimentos (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  categoria text not null,
  porcion text not null,          -- medida casera: '1 taza', '1 filete'
  porcion_g numeric not null,     -- gramos de esa porción
  kcal numeric not null,          -- por 100 g
  prot numeric not null,
  carb numeric not null,
  grasa numeric not null,
  fibra numeric not null default 0,
  activo boolean not null default true
);

create table if not exists public.comidas (
  id bigint generated always as identity primary key,
  client_id uuid not null references public.profiles(id) on delete cascade,
  fecha date not null,
  momento text not null check (momento in ('desayuno','almuerzo','cena','snack')),
  alimento_id bigint references public.alimentos(id) on delete set null,
  nombre text not null,
  gramos numeric not null check (gramos > 0 and gramos <= 3000),
  kcal numeric not null, prot numeric not null, carb numeric not null, grasa numeric not null, fibra numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists comidas_cliente_fecha on public.comidas (client_id, fecha);

create table if not exists public.agua (
  client_id uuid not null references public.profiles(id) on delete cascade,
  fecha date not null,
  vasos integer not null default 0 check (vasos between 0 and 30),
  primary key (client_id, fecha)
);

alter table public.alimentos enable row level security;
alter table public.comidas enable row level security;
alter table public.agua enable row level security;

drop policy if exists "Alimentos: lectura autenticadas" on public.alimentos;
create policy "Alimentos: lectura autenticadas" on public.alimentos for select to authenticated using (true);
drop policy if exists "Alimentos: admin gestiona" on public.alimentos;
create policy "Alimentos: admin gestiona" on public.alimentos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Comidas: propias" on public.comidas;
create policy "Comidas: propias" on public.comidas for all to authenticated using (client_id = auth.uid()) with check (client_id = auth.uid());
drop policy if exists "Comidas: admin lee" on public.comidas;
create policy "Comidas: admin lee" on public.comidas for select to authenticated using (public.is_admin());

drop policy if exists "Agua: propia" on public.agua;
create policy "Agua: propia" on public.agua for all to authenticated using (client_id = auth.uid()) with check (client_id = auth.uid());
drop policy if exists "Agua: admin lee" on public.agua;
create policy "Agua: admin lee" on public.agua for select to authenticated using (public.is_admin());

-- Sin esto la app falla en silencio (pasó con variantes)
grant select, insert, update, delete on public.alimentos, public.comidas, public.agua to authenticated;

insert into public.alimentos (categoria, nombre, porcion, porcion_g, kcal, prot, carb, grasa, fibra) values
-- Cereales, harinas y panes
('Cereales y panes','Arroz blanco cocido','1 taza',160,130,2.7,28.2,0.3,0.4),
('Cereales y panes','Arroz integral cocido','1 taza',160,123,2.7,25.6,1.0,1.6),
('Cereales y panes','Pasta cocida','1 taza',140,158,5.8,30.9,0.9,1.8),
('Cereales y panes','Quinua cocida','1 taza',185,120,4.4,21.3,1.9,2.8),
('Cereales y panes','Avena en hojuelas','3 cucharadas',30,379,13.2,67.7,6.5,10.1),
('Cereales y panes','Granola','1/4 de taza',30,471,10,64,20,5),
('Cereales y panes','Cereal de hojuelas de maíz','1 taza',30,357,7.5,84,0.4,3.3),
('Cereales y panes','Pan blanco','1 tajada',25,265,9,49,3.2,2.7),
('Cereales y panes','Pan integral','1 tajada',30,252,12.4,42.7,3.5,6),
('Cereales y panes','Arepa de maíz blanca','1 arepa mediana',80,200,4.5,40,2.5,3),
('Cereales y panes','Arepa de choclo','1 unidad',100,240,5,38,8,2),
('Cereales y panes','Tortilla de maíz','1 unidad',30,218,5.7,44.6,2.9,6.3),
('Cereales y panes','Galletas de soda','4 unidades',25,421,9.5,71,10,3),
('Cereales y panes','Mazorca cocida','1 unidad',100,96,3.4,21,1.5,2.4),
('Cereales y panes','Pandebono','1 unidad',60,320,11,40,13,1),
('Cereales y panes','Almojábana','1 unidad',60,300,12,35,12,0.5),
('Cereales y panes','Buñuelo','1 unidad',50,350,9,35,20,0.5),
-- Tubérculos y plátano
('Tubérculos y plátano','Papa cocida','1 mediana',150,87,1.9,20.1,0.1,1.8),
('Tubérculos y plátano','Papa criolla cocida','5 unidades',100,92,2,21,0.1,1.8),
('Tubérculos y plátano','Papa a la francesa','1 porción mediana',115,312,3.4,41,15,3.8),
('Tubérculos y plátano','Yuca cocida','1 trozo',100,150,1.2,36,0.3,1.8),
('Tubérculos y plátano','Plátano maduro cocido','1/2 unidad',100,116,0.8,31,0.2,2.3),
('Tubérculos y plátano','Plátano maduro frito (tajadas)','3 tajadas',80,250,1,40,10,2.3),
('Tubérculos y plátano','Plátano verde cocido','1/2 unidad',100,122,1.3,32,0.4,2.3),
('Tubérculos y plátano','Patacón','2 unidades',70,300,1.5,45,13,3),
('Tubérculos y plátano','Batata cocida','1 mediana',130,76,1.4,17.7,0.1,2.5),
-- Leguminosas
('Granos','Fríjoles cocidos','1 taza',170,127,8.7,22.8,0.5,6.4),
('Granos','Lentejas cocidas','1 taza',200,116,9,20.1,0.4,7.9),
('Granos','Garbanzos cocidos','1 taza',165,164,8.9,27.4,2.6,7.6),
('Granos','Arvejas cocidas','1/2 taza',80,84,5.4,15.6,0.2,5.5),
-- Carnes, pollo y pescado
('Carnes, pollo y pescado','Pechuga de pollo a la plancha','1 filete',120,165,31,0,3.6,0),
('Carnes, pollo y pescado','Muslo de pollo sin piel','1 unidad',100,209,26,0,10.9,0),
('Carnes, pollo y pescado','Pollo asado con piel','1 presa',120,239,27,0,13.6,0),
('Carnes, pollo y pescado','Carne de res magra asada','1 porción',120,200,29,0,9,0),
('Carnes, pollo y pescado','Carne molida de res','1/2 taza',100,250,26,0,15,0),
('Carnes, pollo y pescado','Hígado de res','1 porción',100,175,27,5,4.7,0),
('Carnes, pollo y pescado','Lomo de cerdo asado','1 porción',120,196,27,0,9,0),
('Carnes, pollo y pescado','Chicharrón','1 trozo',50,500,25,0,45,0),
('Carnes, pollo y pescado','Chorizo','1 unidad',70,300,15,2,26,0),
('Carnes, pollo y pescado','Salchicha','1 unidad',45,290,11,3,26,0),
('Carnes, pollo y pescado','Jamón de cerdo','1 tajada',20,145,18,2,7,0),
('Carnes, pollo y pescado','Atún en agua','1 lata escurrida',120,116,26,0,0.8,0),
('Carnes, pollo y pescado','Atún en aceite','1 lata escurrida',120,198,29,0,8.2,0),
('Carnes, pollo y pescado','Tilapia a la plancha','1 filete',120,128,26,0,2.7,0),
('Carnes, pollo y pescado','Salmón','1 filete',120,206,22,0,12,0),
('Carnes, pollo y pescado','Mojarra frita','1 porción',150,220,24,4,12,0),
('Carnes, pollo y pescado','Sardinas en salsa de tomate','1/2 lata',75,186,21,2,10,0),
('Carnes, pollo y pescado','Camarones cocidos','1 porción',100,99,24,0.2,0.3,0),
-- Huevos y lácteos
('Huevos y lácteos','Huevo cocido','1 unidad',50,155,12.6,1.1,10.6,0),
('Huevos y lácteos','Huevo frito','1 unidad',50,196,13.6,0.8,14.8,0),
('Huevos y lácteos','Clara de huevo','1 clara',33,52,10.9,0.7,0.2,0),
('Huevos y lácteos','Huevos pericos','1 porción (2 huevos)',130,150,10,3,11,0.5),
('Huevos y lácteos','Leche entera','1 vaso',240,61,3.2,4.8,3.3,0),
('Huevos y lácteos','Leche semidescremada o deslactosada','1 vaso',240,50,3.3,4.8,2,0),
('Huevos y lácteos','Leche descremada','1 vaso',240,34,3.4,5,0.1,0),
('Huevos y lácteos','Yogur griego natural','1 vaso',170,73,9.9,3.9,1.9,0),
('Huevos y lácteos','Yogur con dulce','1 vaso',200,85,3,14,1.8,0),
('Huevos y lácteos','Kumis','1 vaso',200,75,3,11,2,0),
('Huevos y lácteos','Queso campesino','1 tajada',30,250,18,3,19,0),
('Huevos y lácteos','Queso mozzarella','1 tajada',25,280,28,3.1,17,0),
('Huevos y lácteos','Queso doble crema','1 tajada',30,300,20,2,24,0),
('Huevos y lácteos','Cuajada','1 tajada',50,180,14,4,12,0),
('Huevos y lácteos','Proteína en polvo (whey)','1 scoop',30,400,80,8,6,0),
-- Frutas
('Frutas','Banano','1 mediano',120,89,1.1,22.8,0.3,2.6),
('Frutas','Manzana','1 mediana',180,52,0.3,13.8,0.2,2.4),
('Frutas','Pera','1 mediana',180,57,0.4,15.2,0.1,3.1),
('Frutas','Naranja','1 mediana',140,47,0.9,11.8,0.1,2.4),
('Frutas','Mandarina','1 unidad',90,53,0.8,13.3,0.3,1.8),
('Frutas','Papaya','1 taza',150,43,0.5,10.8,0.3,1.7),
('Frutas','Piña','1 taza',165,50,0.5,13.1,0.1,1.4),
('Frutas','Mango','1 taza',165,60,0.8,15,0.4,1.6),
('Frutas','Fresas','1 taza',150,32,0.7,7.7,0.3,2),
('Frutas','Mora','1 taza',140,43,1.4,9.6,0.5,5.3),
('Frutas','Uvas','1 taza',150,69,0.7,18.1,0.2,0.9),
('Frutas','Sandía','1 taza',150,30,0.6,7.6,0.2,0.4),
('Frutas','Melón','1 taza',160,34,0.8,8.2,0.2,0.9),
('Frutas','Guayaba','1 unidad',100,68,2.6,14.3,1,5.4),
('Frutas','Maracuyá (pulpa)','pulpa de 1 unidad',30,97,2.2,23.4,0.7,10.4),
('Frutas','Kiwi','1 unidad',75,61,1.1,14.7,0.5,3),
('Frutas','Aguacate','1/4 de unidad',50,160,2,8.5,14.7,6.7),
-- Verduras
('Verduras','Lechuga','1 taza',50,15,1.4,2.9,0.2,1.3),
('Verduras','Tomate','1 mediano',120,18,0.9,3.9,0.2,1.2),
('Verduras','Zanahoria','1 mediana',70,41,0.9,9.6,0.2,2.8),
('Verduras','Brócoli cocido','1 taza',150,35,2.4,7.2,0.4,3.3),
('Verduras','Espinaca cocida','1/2 taza',90,23,3,3.8,0.3,2.4),
('Verduras','Pepino','1/2 unidad',100,15,0.7,3.6,0.1,0.5),
('Verduras','Cebolla','1/2 unidad',50,40,1.1,9.3,0.1,1.7),
('Verduras','Habichuela cocida','1/2 taza',60,35,1.9,7.9,0.3,3.2),
('Verduras','Ahuyama cocida','1/2 taza',120,20,0.7,4.9,0.1,1.1),
('Verduras','Champiñones','1 taza',70,22,3.1,3.3,0.3,1),
('Verduras','Remolacha cocida','1/2 taza',85,44,1.7,10,0.2,2),
('Verduras','Calabacín','1 taza',120,17,1.2,3.1,0.3,1),
('Verduras','Ensalada de lechuga, tomate y pepino','1 plato',150,18,1,3.5,0.2,1.2),
-- Grasas y semillas
('Grasas y semillas','Aceite (oliva o vegetal)','1 cucharada',14,884,0,0,100,0),
('Grasas y semillas','Mantequilla','1 cucharadita',5,717,0.9,0.1,81,0),
('Grasas y semillas','Mayonesa','1 cucharada',15,680,1,0.6,75,0),
('Grasas y semillas','Mantequilla de maní','1 cucharada',16,588,25,20,50,6),
('Grasas y semillas','Maní','1 puñado',30,567,25.8,16.1,49.2,8.5),
('Grasas y semillas','Almendras','1 puñado',30,579,21.2,21.6,49.9,12.5),
('Grasas y semillas','Nueces','1 puñado',30,654,15.2,13.7,65.2,6.7),
('Grasas y semillas','Chía','1 cucharada',12,486,16.5,42,30.7,34.4),
-- Bebidas
('Bebidas','Tinto (café negro)','1 taza',240,2,0.1,0,0,0),
('Bebidas','Café con leche','1 taza',240,35,1.7,2.7,1.8,0),
('Bebidas','Chocolate en leche','1 taza',240,90,3.4,12,3.5,0.5),
('Bebidas','Jugo de naranja natural','1 vaso',240,45,0.7,10.4,0.2,0.2),
('Bebidas','Jugo de fruta en agua con azúcar','1 vaso',240,45,0.2,11,0,0.3),
('Bebidas','Jugo de fruta en leche','1 vaso',240,75,2.5,12,2,0.3),
('Bebidas','Agua de panela','1 vaso',240,30,0,7.6,0,0),
('Bebidas','Gaseosa','1 vaso',250,42,0,10.6,0,0),
('Bebidas','Cerveza','1 lata',330,43,0.5,3.6,0,0),
('Bebidas','Vino tinto','1 copa',150,85,0.1,2.6,0,0),
-- Dulces y paquetes
('Dulces y paquetes','Azúcar','1 cucharadita',5,387,0,100,0,0),
('Dulces y paquetes','Panela','1 trozo',20,380,0.4,95,0.1,0),
('Dulces y paquetes','Miel','1 cucharada',21,304,0.3,82.4,0,0.2),
('Dulces y paquetes','Arequipe','1 cucharada',20,315,6.8,55,7.4,0),
('Dulces y paquetes','Bocadillo','1 unidad',30,290,0.4,72,0.1,2),
('Dulces y paquetes','Chocolatina','1 unidad',25,535,7.7,59.4,29.7,3.4),
('Dulces y paquetes','Chocolate oscuro 70%','2 cuadritos',20,598,7.8,45.9,42.6,10.9),
('Dulces y paquetes','Helado de crema','1 bola',70,207,3.5,23.6,11,0.7),
('Dulces y paquetes','Ponqué o torta','1 tajada',60,389,5.5,49,19,0.5),
('Dulces y paquetes','Galletas dulces','3 unidades',30,480,6,68,20,2),
('Dulces y paquetes','Barra de cereal','1 unidad',25,400,6,70,10,4),
('Dulces y paquetes','Papas de paquete','1 paquete',30,536,7,53,35,4.8),
-- Platos típicos (aproximados: dependen de la receta)
('Platos','Empanada frita de carne','1 unidad',90,280,8,28,15,2),
('Platos','Sopa de verduras','1 plato',300,35,1.5,6,0.6,1.2),
('Platos','Sancocho de gallina','1 plato',400,75,5,8,2.5,1),
('Platos','Ajiaco','1 plato',400,90,5,10,3,1.3),
('Platos','Caldo de costilla','1 plato',300,60,4,4,3,0.5),
('Platos','Changua','1 plato',300,60,4,4,3,0),
('Platos','Arroz con pollo','1 plato',300,160,8,20,5,0.8),
('Platos','Calentado','1 porción',250,180,6,25,6,4),
('Platos','Bandeja paisa','1 plato',700,170,8,16,8,3),
('Platos','Tamal','1 unidad',400,160,6,18,7,2),
('Platos','Pizza','1 porción',110,266,11,33,10,2.3),
('Platos','Hamburguesa','1 unidad',200,254,13,30,9,1),
('Platos','Perro caliente','1 unidad',150,270,9,24,15,1)
on conflict (nombre) do nothing;

-- Rollback:
-- drop table if exists public.agua; drop table if exists public.comidas; drop table if exists public.alimentos;
