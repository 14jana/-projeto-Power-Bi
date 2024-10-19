

SELECT * 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME = 'DIM_TEMPO' AND TABLE_SCHEMA = 'DM';

SELECT * 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME = 'DIM_TEMPO';

-- PROC TRANSFORMA��O E CARGA DIM TEMPO
CREATE PROCEDURE TRA.LOAD_DIM_TEMPO
AS
BEGIN
    SET NOCOUNT ON;

    -- DECLARANDO AS VARI�VEIS
    DECLARE @DATA DATE = '20000101';
    DECLARE @DATA_FIM DATE = '20301231';

    -- PERCORRENDO TODAS AS DATAS
    WHILE @DATA <= @DATA_FIM
    BEGIN
        -- INSERINDO OS DADOS NA DIMENS�O TEMPO
        INSERT INTO DM.DIM_TEMPO (
            sk_tempo,
            dt_tempo,
            nr_ano,
            nr_mes,
            nr_semestre,
            nr_trimestre,
            nm_mes,
            nm_mes_abreviado,
            ds_semestre,
            ds_trimestre
        )
        VALUES (
            CAST(FORMAT(@DATA, 'yyyyMMdd') AS INT),        -- sk_tempo
            @DATA,                                         -- dt_tempo
            YEAR(@DATA),                                   -- nr_ano
            MONTH(@DATA),                                  -- nr_mes
            CASE WHEN MONTH(@DATA) <= 6 THEN 1 ELSE 2 END, -- nr_semestre
            DATEPART(QUARTER, @DATA),                      -- nr_trimestre
            FORMAT(@DATA, 'MMMM', 'pt-BR'),                -- nm_mes
            FORMAT(@DATA, 'MMM', 'pt-BR'),                 -- nm_mes_abreviado
            CONCAT(CASE WHEN MONTH(@DATA) <= 6 THEN 1 ELSE 2 END, 'S'), -- ds_semestre
            CONCAT(DATEPART(QUARTER, @DATA), 'T')          -- ds_trimestre
        );

        -- Incrementando o dia
        SET @DATA = DATEADD(DAY, 1, @DATA);
    END
END;
GO

SELECT TOP 10 * FROM DM.DIM_TEMPO ORDER BY dt_tempo DESC;
GO

-------------------------------------------------------------------------------------------------------------------------------------

SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TB_DESPESA' 
  AND TABLE_SCHEMA = 'ext';


-- Remover a tabela auxiliar se existir
IF OBJECT_ID('TRA.AUX_LOCALIDADE', 'U') IS NOT NULL
    DROP TABLE TRA.AUX_LOCALIDADE;

GO 
 
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TB_DESPESA' 
  AND TABLE_SCHEMA = 'ext';

  -- Remover a tabela auxiliar se existir
IF OBJECT_ID('TRA.AUX_LOCALIDADE', 'U') IS NOT NULL
    DROP TABLE TRA.AUX_LOCALIDADE;

GO  -- Iniciar um novo lote

CREATE PROCEDURE TRA.LOAD_DIM_LOCALIDADE
AS
BEGIN
    SET NOCOUNT ON;

    -- Remover a tabela auxiliar se existir
    IF OBJECT_ID('TRA.AUX_LOCALIDADE', 'U') IS NOT NULL
    BEGIN
        DROP TABLE TRA.AUX_LOCALIDADE;
    END

    -- Criar a tabela auxiliar
    CREATE TABLE TRA.AUX_LOCALIDADE (
        SK_LOCALIDADE INT IDENTITY(1,1) PRIMARY KEY,
        SG_REGIAO NVARCHAR(2),
        NM_REGIAO NVARCHAR(100),
        SG_UF NVARCHAR(2),
        NM_UF NVARCHAR(100),
        NM_MUNICIPIO NVARCHAR(250)
    );

    -- Inserir dados na tabela auxiliar
    INSERT INTO TRA.AUX_LOCALIDADE (SG_REGIAO, NM_REGIAO, SG_UF, NM_UF, NM_MUNICIPIO)
    SELECT 
        CASE 
            WHEN UF IS NOT NULL THEN
                CASE 
                    WHEN UF IN ('DF', 'GO', 'MT', 'MS') THEN 'CO'  -- Centro-Oeste
                    WHEN UF IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'NE'  -- Nordeste
                    WHEN UF IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'NO'  -- Norte
                    WHEN UF IN ('ES', 'MG', 'RJ', 'SP') THEN 'SD'  -- Sudeste
                    WHEN UF IN ('PR', 'RS', 'SC') THEN 'SL'  -- Sul
                    ELSE 'SI'  -- Sem Informa��o
                END
            ELSE 
                CASE 
                    WHEN SIGLA_LOCALIZADOR = '-1' THEN 'SI'
                    ELSE SIGLA_LOCALIZADOR
                END
        END AS SG_REGIAO,
        
        CASE 
            WHEN UF IS NOT NULL THEN
                CASE 
                    WHEN UF IN ('DF', 'GO', 'MT', 'MS') THEN 'CENTRO-OESTE'
                    WHEN UF IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'NORDESTE'
                    WHEN UF IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'NORTE'
                    WHEN UF IN ('ES', 'MG', 'RJ', 'SP') THEN 'SUDESTE'
                    WHEN UF IN ('PR', 'RS', 'SC') THEN 'SUL'
                    ELSE 'Sem Informa��o'
                END
            ELSE 
                CASE 
                    WHEN CHARINDEX('NA REGI�O', NOME_LOCALIZADOR) > 0 THEN REPLACE(NOME_LOCALIZADOR, 'NA REGI�O ', '')
                    WHEN CHARINDEX('NO ', NOME_LOCALIZADOR) > 0 THEN REPLACE(NOME_LOCALIZADOR, 'NO ', '')
                    ELSE NOME_LOCALIZADOR
                END
        END AS NM_REGIAO,

        CASE 
            WHEN UF IS NULL OR UF = '' THEN 'SI'
            ELSE UF
        END AS SG_UF,

        CASE 
            WHEN UF IS NULL OR UF = '' THEN 'Sem Informa��o'
            ELSE CASE 
                WHEN UF = 'SP' THEN 'S�O PAULO'
                WHEN UF = 'RJ' THEN 'RIO DE JANEIRO'
                -- Adicione todos os outros estados aqui...
                ELSE 'Sem Informa��o' -- Para os outros estados
            END
        END AS NM_UF,

        CASE 
            WHEN MUNICIPIO IS NULL OR MUNICIPIO = '' THEN 'Sem Informa��o'
            ELSE MUNICIPIO
        END AS NM_MUNICIPIO

    FROM ext.TB_DESPESA;

    -- Inserir os dados tratados na tabela DIM_LOCALIDADE
    INSERT INTO DM.DIM_LOCALIDADE (SG_REGIAO, NM_REGIAO, SG_UF, NM_UF, NM_MUNICIPIO)
    SELECT DISTINCT 
        SG_REGIAO, NM_REGIAO, SG_UF, NM_UF, NM_MUNICIPIO
    FROM TRA.AUX_LOCALIDADE;

END;
GO

SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'DIM_LOCALIDADE' AND TABLE_SCHEMA = 'DM';

SELECT TOP 10 *
FROM DM.DIM_LOCALIDADE
ORDER BY NM_MUNICIPIO DESC;
GO


-------------------------------------------------------------------------------------------------------------

CREATE TABLE SK_GESTAO (
    procidulr INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_GESTAO INT NOT NULL DEFAULT -1,        -- C�digo da gest�o, padr�o -1 se nulo ou vazio
    NM_GESTAO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome da gest�o, padr�o 'Sem informa��o'
    CD_GESTORA INT NOT NULL,                   -- C�digo da unidade gestora
    NM_GESTORA VARCHAR(255) NOT NULL,         -- Nome da unidade gestora
    CD_UNIDADE INT NOT NULL,                   -- C�digo da unidade or�ament�ria
    NM_UNIDADE VARCHAR(255) NOT NULL           -- Nome da unidade or�ament�ria
);

-- Inserir dados na tabela SK_GESTAO a partir da tabela de origem ext.TB_DESPESA
INSERT INTO SK_GESTAO (CD_GESTAO, NM_GESTAO, CD_GESTORA, NM_GESTORA, CD_UNIDADE, NM_UNIDADE)
SELECT 
    ISNULL(CODIGO_GESTAO, -1) AS CD_GESTAO,  -- Tratamento para valor nulo
    ISNULL(NOME_GESTAO, 'Sem informa��o') AS NM_GESTAO, -- Tratamento para valor nulo
    CODIGO_UNIDADE_GESTORA AS CD_GESTORA,
    NOME_UNIDADE_GESTORA AS NM_GESTORA,
    CODIGO_UNIDADE_ORCAMENTARIA AS CD_UNIDADE,
    NOME_UNIDADE_ORCAMENTARIA AS NM_UNIDADE
FROM ext.TB_DESPESA;


SELECT *
FROM SK_GESTAO;



----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE SK_FUNCAO (
    procidule INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_FUNCAO INT NOT NULL,                   -- C�digo da fun��o
    NM_FUNCAO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome da fun��o
    CD_SUBFUNCAO INT NOT NULL,                -- C�digo da subfun��o
    NM_SUBFUNCAO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o' -- Nome da subfun��o
);
-- Inserir dados na tabela SK_FUNCAO a partir da tabela de origem ext.TB_DESPESA
INSERT INTO SK_FUNCAO (CD_FUNCAO, NM_FUNCAO, CD_SUBFUNCAO, NM_SUBFUNCAO)
SELECT 
    CODIGO_FUNCAO AS CD_FUNCAO,
    ISNULL(NOME_FUNCAO, 'Sem informa��o') AS NM_FUNCAO, -- Tratamento para valor nulo
    CODIGO_SUBFUCAO AS CD_SUBFUNCAO,
    ISNULL(NOME_SUBFUNCAO, 'Sem informa��o') AS NM_SUBFUNCAO -- Tratamento para valor nulo
FROM ext.TB_DESPESA;

SELECT 
    procidule, 
    CD_FUNCAO, 
    NM_FUNCAO, 
    CD_SUBFUNCAO, 
    NM_SUBFUNCAO
FROM SK_FUNCAO
ORDER BY procidule; -- Ordena os resultados pelo identificador

SELECT *
FROM SK_FUNCAO;

SELECT *
FROM SK_FUNCAO
WHERE NM_FUNCAO = 'Sem informa��o';

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE SK_MODALIDADE (
    procidule INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_MODALIDADE INT NOT NULL,                -- C�digo da modalidade
    NM_MODALIDADE VARCHAR(255) NOT NULL        -- Nome da modalidade
);

INSERT INTO SK_MODALIDADE (CD_MODALIDADE, NM_MODALIDADE)
SELECT 
    CODIGO_MODALIDADE_DA_DESPESA AS CD_MODALIDADE,
    MAX(MODALIDADE_DA_DESPESA) AS NM_MODALIDADE -- Seleciona a descri��o mais completa
FROM ext.TB_DESPESA
GROUP BY CODIGO_MODALIDADE_DA_DESPESA; -- Agrupa por c�digo para evitar duplicatas

SELECT 
    procidule, 
    CD_MODALIDADE, 
    NM_MODALIDADE
FROM SK_MODALIDADE
ORDER BY procidule; -- Ordena os resultados pelo identificador

SELECT *
FROM SK_MODALIDADE
WHERE CD_MODALIDADE = 31; -- Exemplo de filtro para o c�digo 31

SELECT *
FROM SK_MODALIDADE;

--------------------------------------------------------------------------------------------------------
CREATE TABLE SK_ACAO (
    procidule INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_ACAO VARCHAR(255) NOT NULL,            -- C�digo da a��o or�ament�ria (definir como VARCHAR)
    NM_ACAO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome da a��o or�ament�ria
    CD_PLANO VARCHAR(255) NOT NULL,           -- C�digo do plano or�ament�rio (definir como VARCHAR)
    NM_PLANO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome do plano or�ament�rio
    CD_SUB_ACAO VARCHAR(255) NOT NULL,        -- C�digo da sub a��o or�ament�ria (definir como VARCHAR)
    NM_SUB_ACAO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o' -- Nome da sub a��o or�ament�ria
);


INSERT INTO SK_ACAO (CD_ACAO, NM_ACAO, CD_PLANO, NM_PLANO, CD_SUB_ACAO, NM_SUB_ACAO)
SELECT 
    CODIGO_ACAO AS CD_ACAO,
    ISNULL(NOME_ACAO, 'Sem informa��o') AS NM_ACAO, -- Tratamento para valor nulo
    CODIGO_PLANO_ORCAMENTARIO AS CD_PLANO,
    ISNULL(PLANO_ORCAMENTARIO, 'Sem informa��o') AS NM_PLANO, -- Tratamento para valor nulo
    CODIGO_SUBTITULO AS CD_SUB_ACAO,
    ISNULL(NOME_SUBTITULO, 'Sem informa��o') AS NM_SUB_ACAO -- Tratamento para valor nulo
FROM ext.TB_DESPESA;

SELECT 
    procidule, 
    CD_ACAO, 
    NM_ACAO, 
    CD_PLANO, 
    NM_PLANO, 
    CD_SUB_ACAO, 
    NM_SUB_ACAO
FROM SK_ACAO
ORDER BY procidule; -- Ordena os resultados pelo identificador

SELECT *
FROM SK_ACAO;

-----------------------------------------------------------------------------------------------------

CREATE TABLE SK_PROGRAMA (
    procidule INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_PROGRAMA_ORCAMENTARIO VARCHAR(255) NOT NULL, -- C�digo do programa or�ament�rio
    NM_PROGRAMA_ORCAMENTARIO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome do programa or�ament�rio
    CD_PROGRAMA_GOVERNO VARCHAR(255) NOT NULL,  -- C�digo do programa de governo
    NM_PROGRAMA_GOVERNO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o' -- Nome do programa de governo
);

INSERT INTO SK_PROGRAMA (CD_PROGRAMA_ORCAMENTARIO, NM_PROGRAMA_ORCAMENTARIO, CD_PROGRAMA_GOVERNO, NM_PROGRAMA_GOVERNO)
SELECT 
    CODIGO_PROGRAMA_ORCAMENTARIO AS CD_PROGRAMA_ORCAMENTARIO,
    ISNULL(NOME_PROGRAMA_ORCAMENTARIO, 'Sem informa��o') AS NM_PROGRAMA_ORCAMENTARIO,
    CASE 
        WHEN CODIGO_PROGRAMA_GOVERNO = '00' AND NOME_PROGRAMA_GOVERNO = 'TRAVESSIAS' THEN '00T' 
        ELSE CODIGO_PROGRAMA_GOVERNO 
    END AS CD_PROGRAMA_GOVERNO,  -- Tratamento para o c�digo do programa de governo
    ISNULL(NOME_PROGRAMA_GOVERNO, 'Sem informa��o') AS NM_PROGRAMA_GOVERNO
FROM ext.TB_DESPESA;


SELECT 
    procidule, 
    CD_PROGRAMA_ORCAMENTARIO, 
    NM_PROGRAMA_ORCAMENTARIO,
    CD_PROGRAMA_GOVERNO,
    NM_PROGRAMA_GOVERNO
FROM SK_PROGRAMA
ORDER BY procidule; -- Ordena os resultados pelo identificador

SELECT *
FROM SK_PROGRAMA;


---------------------------------------------------------------------------------------------------
CREATE TABLE SK_ORGAO (
    procidule INT IDENTITY(1,1) PRIMARY KEY,  -- Identificador �nico, auto numera��o
    CD_ORGAO_SUPERIOR VARCHAR(255) NOT NULL, -- C�digo do �rg�o Superior
    NM_ORGAO_SUPERIOR VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o', -- Nome do �rg�o Superior
    CD_ORGAO_SUBORDINADO VARCHAR(255) NOT NULL, -- C�digo do �rg�o Subordinado
    NM_ORGAO_SUBORDINADO VARCHAR(255) NOT NULL DEFAULT 'Sem informa��o' -- Nome do �rg�o Subordinado
);

INSERT INTO SK_ORGAO (CD_ORGAO_SUPERIOR, NM_ORGAO_SUPERIOR, CD_ORGAO_SUBORDINADO, NM_ORGAO_SUBORDINADO)
SELECT 
    CODIGO_ORGAO_SUPERIOR AS CD_ORGAO_SUPERIOR,
    ISNULL(NOME_ORGAO_SUPERIOR, 'Sem informa��o') AS NM_ORGAO_SUPERIOR,
    CODIGO_ORGAO_SUBORDINADO AS CD_ORGAO_SUBORDINADO,
    ISNULL(NOME_ORGAO_SUBORDINADO, 'Sem informa��o') AS NM_ORGAO_SUBORDINADO
FROM ext.TB_DESPESA;
SELECT 
    procidule, 
    CD_ORGAO_SUPERIOR, 
    NM_ORGAO_SUPERIOR,
    CD_ORGAO_SUBORDINADO,
    NM_ORGAO_SUBORDINADO
FROM SK_ORGAO
ORDER BY procidule; -- Ordena os resultados pelo identificador


SELECT *
FROM SK_ORGAO;

------------------------------------------------------------------------------------------------------


CREATE OR ALTER PROCEDURE TRA.LOAD_FATO_DESPESA  -- Use CREATE OR ALTER para facilitar ajustes futuros
AS
BEGIN
    SET NOCOUNT ON;  
    INSERT INTO DM.FATO_DESPESA (
        ANO_MES_LANCAMENTO,
        SK_TEMPO,
        SK_ORGAO,
        SK_GESTAO,
        SK_FUNCAO,
        SK_MODALIDADE,
        SK_ACAO,
        SK_PROGRAMA,
        SK_LOCALIDADE,
        VL_EMPENHADO,
        VL_LIQUIDADO,
        VL_PAGO,
        VL_INSCRITO,
        VL_CANCELADO,
        VL_APAGAR_PAGO
    )
    SELECT
        -- ANO_MES_LANCAMENTO ser� usado diretamente da origem
        DESP.ANO_MES_LANCAMENTO,
        
        -- SK_TEMPO: Recuperado da dimens�o de tempo atrav�s da data de lan�amento
        (SELECT SK_TEMPO FROM DM.DIM_TEMPO WHERE dt_tempo = DESP.ANO_MES_LANCAMENTO) AS SK_TEMPO,

        -- SK_ORGAO: Recuperado atrav�s do c�digo do �rg�o superior e subordinado
        (SELECT SK_ORGAO FROM DM.DIM_ORGAO 
         WHERE CD_ORGAO_SUPERIOR = DESP.CODIGO_ORGAO_SUPERIOR 
           AND CD_ORGAO_SUBORDINADO = DESP.CODIGO_ORGAO_SUBORDINADO) AS SK_ORGAO,

        -- SK_GESTAO: Recuperado atrav�s do c�digo da gest�o
        (SELECT SK_GESTAO FROM DM.DIM_GESTAO 
         WHERE CD_GESTAO = DESP.CODIGO_GESTAO 
           AND CD_GESTORA = DESP.CODIGO_UNIDADE_GESTORA) AS SK_GESTAO,

        -- SK_FUNCAO: Recuperado atrav�s do c�digo da fun��o e subfun��o
        (SELECT SK_FUNCAO FROM DM.DIM_FUNCAO 
         WHERE CD_FUNCAO = DESP.CODIGO_FUNCAO 
           AND CD_SUBFUNCAO = DESP.CODIGO_SUBFUCAO) AS SK_FUNCAO,

        -- SK_MODALIDADE: Recuperado atrav�s do c�digo da modalidade da despesa
        (SELECT SK_MODALIDADE FROM DM.DIM_MODALIDADE 
         WHERE CD_MODALIDADE = DESP.CODIGO_MODALIDADE_DA_DESPESA) AS SK_MODALIDADE,

        -- SK_ACAO: Recuperado atrav�s do c�digo da a��o e do plano or�ament�rio
        (SELECT SK_ACAO FROM DM.DIM_ACAO 
         WHERE CD_ACAO = DESP.CODIGO_ACAO 
           AND CD_PLANO = DESP.CODIGO_PLANO_ORCAMENTARIO) AS SK_ACAO,

        -- SK_PROGRAMA: Recuperado atrav�s do c�digo do programa or�ament�rio e de governo
        (SELECT SK_PROGRAMA FROM DM.DIM_PROGRAMA 
         WHERE CD_PROGRAMA_ORCAMENTARIO = DESP.CODIGO_PROGRAMA_ORCAMENTARIO 
           AND CD_PROGRAMA_GOVERNO = DESP.CODIGO_PROGRAMA_GOVERNO) AS SK_PROGRAMA,

        -- SK_LOCALIDADE: Recuperado atrav�s da UF e munic�pio
        (SELECT SK_LOCALIDADE FROM DM.DIM_LOCALIDADE 
         WHERE SG_UF = DESP.UF 
           AND NM_MUNICIPIO = DESP.MUNICIPIO) AS SK_LOCALIDADE,

        -- Valores financeiros
        DESP.VALOR_EMPENHADO AS VL_EMPENHADO,      -- Valor empenhado
        DESP.VALOR_LIQUIDADO AS VL_LIQUIDADO,      -- Valor liquidado
        DESP.VALOR_PAGO AS VL_PAGO,                -- Valor pago
        DESP.VALOR_RESTOS_A_PAGAR_INSCRITOS AS VL_INSCRITO,  -- Valor restos a pagar inscritos
        DESP.VALOR_RESTOS_A_PAGAR_CANCELADO AS VL_CANCELADO, -- Valor restos a pagar cancelado
        DESP.VALOR_RESTOS_A_PAGAR_PAGOS AS VL_APAGAR_PAGO    -- Valor restos a pagar pagos

    FROM 
        ext.TB_DESPESA DESP;  -- Tabela de origem

END;
GO
-- Certifique-se de que este � o primeiro comando no script ou lote.
GO  -- Se houver comandos antes, use GO para separar

CREATE OR ALTER PROCEDURE TRA.LOAD_FATO_DESPESA  -- Use CREATE OR ALTER para facilitar ajustes futuros
AS
BEGIN
    SET NOCOUNT ON;  -- Evita que o SQL Server retorne contagens desnecess�rias de linhas afetadas

    -- Inserindo dados na tabela Fato de Despesa
    INSERT INTO DM.FATO_DESPESA (
        ANO_MES_LANCAMENTO,
        SK_TEMPO,
        SK_ORGAO,
        SK_GESTAO,
        SK_FUNCAO,
        SK_MODALIDADE,
        SK_ACAO,
        SK_PROGRAMA,
        SK_LOCALIDADE,
        VL_EMPENHADO,
        VL_LIQUIDADO,
        VL_PAGO,
        VL_INSCRITO,
        VL_CANCELADO,
        VL_APAGAR_PAGO
    )
    SELECT
        -- ANO_MES_LANCAMENTO ser� usado diretamente da origem
        DESP.ANO_MES_LANCAMENTO,
        
        -- SK_TEMPO: Recuperado da dimens�o de tempo atrav�s da data de lan�amento
        (SELECT SK_TEMPO FROM DM.DIM_TEMPO WHERE dt_tempo = DESP.ANO_MES_LANCAMENTO) AS SK_TEMPO,

        -- SK_ORGAO: Recuperado atrav�s do c�digo do �rg�o superior e subordinado
        (SELECT SK_ORGAO FROM DM.DIM_ORGAO 
         WHERE CD_ORGAO_SUPERIOR = DESP.CODIGO_ORGAO_SUPERIOR 
           AND CD_ORGAO_SUBORDINADO = DESP.CODIGO_ORGAO_SUBORDINADO) AS SK_ORGAO,

        -- SK_GESTAO: Recuperado atrav�s do c�digo da gest�o
        (SELECT SK_GESTAO FROM DM.DIM_GESTAO 
         WHERE CD_GESTAO = DESP.CODIGO_GESTAO 
           AND CD_GESTORA = DESP.CODIGO_UNIDADE_GESTORA) AS SK_GESTAO,

        -- SK_FUNCAO: Recuperado atrav�s do c�digo da fun��o e subfun��o
        (SELECT SK_FUNCAO FROM DM.DIM_FUNCAO 
         WHERE CD_FUNCAO = DESP.CODIGO_FUNCAO 
           AND CD_SUBFUNCAO = DESP.CODIGO_SUBFUCAO) AS SK_FUNCAO,

        -- SK_MODALIDADE: Recuperado atrav�s do c�digo da modalidade da despesa
        (SELECT SK_MODALIDADE FROM DM.DIM_MODALIDADE 
         WHERE CD_MODALIDADE = DESP.CODIGO_MODALIDADE_DA_DESPESA) AS SK_MODALIDADE,

        -- SK_ACAO: Recuperado atrav�s do c�digo da a��o e do plano or�ament�rio
        (SELECT SK_ACAO FROM DM.DIM_ACAO 
         WHERE CD_ACAO = DESP.CODIGO_ACAO 
           AND CD_PLANO = DESP.CODIGO_PLANO_ORCAMENTARIO) AS SK_ACAO,

        -- SK_PROGRAMA: Recuperado atrav�s do c�digo do programa or�ament�rio e de governo
        (SELECT SK_PROGRAMA FROM DM.DIM_PROGRAMA 
         WHERE CD_PROGRAMA_ORCAMENTARIO = DESP.CODIGO_PROGRAMA_ORCAMENTARIO 
           AND CD_PROGRAMA_GOVERNO = DESP.CODIGO_PROGRAMA_GOVERNO) AS SK_PROGRAMA,

        -- SK_LOCALIDADE: Recuperado atrav�s da UF e munic�pio
        (SELECT SK_LOCALIDADE FROM DM.DIM_LOCALIDADE 
         WHERE SG_UF = DESP.UF 
           AND NM_MUNICIPIO = DESP.MUNICIPIO) AS SK_LOCALIDADE,

        -- Valores financeiros
        DESP.VALOR_EMPENHADO AS VL_EMPENHADO,      -- Valor empenhado
        DESP.VALOR_LIQUIDADO AS VL_LIQUIDADO,      -- Valor liquidado
        DESP.VALOR_PAGO AS VL_PAGO,                -- Valor pago
        DESP.VALOR_RESTOS_A_PAGAR_INSCRITOS AS VL_INSCRITO,  -- Valor restos a pagar inscritos
        DESP.VALOR_RESTOS_A_PAGAR_CANCELADO AS VL_CANCELADO, -- Valor restos a pagar cancelado
        DESP.VALOR_RESTOS_A_PAGAR_PAGOS AS VL_APAGAR_PAGO    -- Valor restos a pagar pagos



    FROM 
        ext.TB_DESPESA DESP;  -- Tabela de origem

END;
GO





SELECT TOP 100 * 
FROM DM.FATO_DESPESA;


SELECT * 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TB_DESPESA' AND TABLE_SCHEMA = 'ext';

SELECT * 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'DIM_EMENDA' AND TABLE_SCHEMA = 'DM';

SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME = 'FATO_DESPESA';

CREATE OR ALTER PROCEDURE TRA.LOAD_FATO_DESPESA  
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO DM.FATO_DESPESA (
        ANO_MES_LANCAMENTO,
        SK_TEMPO,
        SK_ORGAO,
        SK_GESTAO,
        SK_FUNCAO,
        SK_MODALIDADE,
        SK_ACAO,
        SK_PROGRAMA,
        SK_LOCALIDADE,
        VL_EMPENHADO,
        VL_LIQUIDADO,
        VL_PAGO,
        VL_INSCRITO,
        VL_CANCELADO,
        VL_APAGAR_PAGO
    )
    SELECT
        DESP.ANO_MES_LANCAMENTO,
        
        -- SK_TEMPO
        (SELECT SK_TEMPO FROM DM.DIM_TEMPO WHERE FORMAT(dt_tempo, 'yyyyMM') = DESP.ANO_MES_LANCAMENTO) AS SK_TEMPO,

        -- SK_ORGAO
        (SELECT SK_ORGAO FROM DM.DIM_ORGAO 
         WHERE CD_ORGAO_SUPERIOR = DESP.CODIGO_ORGAO_SUPERIOR 
           AND CD_ORGAO_SUBORDINADO = DESP.CODIGO_ORGAO_SUBORDINADO) AS SK_ORGAO,

        -- SK_GESTAO
        (SELECT SK_GESTAO FROM DM.DIM_GESTAO 
         WHERE CD_GESTAO = DESP.CODIGO_GESTAO 
           AND CD_GESTORA = DESP.CODIGO_UNIDADE_GESTORA) AS SK_GESTAO,

        -- SK_FUNCAO
        (SELECT SK_FUNCAO FROM DM.DIM_FUNCAO 
         WHERE CD_FUNCAO = DESP.CODIGO_FUNCAO 
           AND CD_SUBFUNCAO = DESP.CODIGO_SUBFUCAO) AS SK_FUNCAO,

        -- SK_MODALIDADE
        (SELECT SK_MODALIDADE FROM DM.DIM_MODALIDADE 
         WHERE CD_MODALIDADE = DESP.CODIGO_MODALIDADE_DA_DESPESA) AS SK_MODALIDADE,

        -- SK_ACAO
        (SELECT SK_ACAO FROM DM.DIM_ACAO 
         WHERE CD_ACAO = DESP.CODIGO_ACAO 
           AND CD_PLANO = DESP.CODIGO_PLANO_ORCAMENTARIO) AS SK_ACAO,

        -- SK_PROGRAMA
        (SELECT SK_PROGRAMA FROM DM.DIM_PROGRAMA 
         WHERE CD_PROGRAMA_ORCAMENTARIO = DESP.CODIGO_PROGRAMA_ORCAMENTARIO 
           AND CD_PROGRAMA_GOVERNO = DESP.CODIGO_PROGRAMA_GOVERNO) AS SK_PROGRAMA,

        -- SK_LOCALIDADE
        (SELECT SK_LOCALIDADE FROM DM.DIM_LOCALIDADE 
         WHERE SG_UF = DESP.UF 
           AND NM_MUNICIPIO = DESP.MUNICIPIO) AS SK_LOCALIDADE,

        -- Valores financeiros
        DESP.VALOR_EMPENHADO AS VL_EMPENHADO,
        DESP.VALOR_LIQUIDADO AS VL_LIQUIDADO,
        DESP.VALOR_PAGO AS VL_PAGO,
        DESP.VALOR_RESTOS_A_PAGAR_INSCRITOS AS VL_INSCRITO,
        DESP.VALOR_RESTOS_A_PAGAR_CANCELADO AS VL_CANCELADO,
        DESP.VALOR_RESTOS_A_PAGAR_PAGOS AS VL_APAGAR_PAGO

    FROM ext.TB_DESPESA DESP;

END;
GO




